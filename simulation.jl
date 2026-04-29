using CSV
using DataFrames
using SpecialFunctions # Per erf
using Plots
using ProgressMeter    # Il "tqdm" di Julia
using LaTeXStrings     # Per il supporto LaTeX nativo
using Printf
using Statistics
using LinearAlgebra
using Random
using DelimitedFiles
using LsqFit

# --- CONFIGURAZIONE ---
const MAX_SAMPLES = 1e9
const N_VALUES = [32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384]
const SCALING_FACTOR = 2.0

"""
Esegue il binario drunkMan
"""
function run_drunk_man(N::Int, samples::Int, label::String)
    samples_to_run = min(samples, Int(MAX_SAMPLES))
    if samples_to_run != samples
        @warn "Forse è meglio che rituni i parametri..."
        exit(-1)
    end

    outfile = "./data/test_$(label)_N$N.txt"
        @printf("Simulazione  -> N=%d, Samples=%d...\n", N, samples_to_run)

    # Crea la cartella data se non esiste
    mkpath("./data")

    # Costruisce il comando shell
    cmd = `./build/drunkMan $N $samples_to_run $outfile`

    try
        run(cmd) # Esegue il comando (simulazioni già fatte)
        return outfile
    catch e
        println("Errore nell'esecuzione: $e")
        return nothing
    end
end

"""
Carica i dati in modo robusto
"""
function load_data_safe(filename::String)
    try
        # Legge il file ignorando i nomi delle colonne originali e forzando x, y
        df = CSV.read(filename, DataFrame; header=1)
        # Seleziona le prime due colonne
        clean_df = df[:, 1:2]
        rename!(clean_df, [:x, :y])
        return clean_df
    catch e
        println("Errore caricamento $filename: $e")
        return nothing
    end
end

# --- FUNZIONI DI SUPPORTO PER FENWICK TREE ---
function bit_update!(bit::Vector{Int}, idx::Int, val::Int)
    n = length(bit)
    while idx <= n
        bit[idx] += val
        idx += idx & (-idx)
    end
end

function bit_query(bit::Vector{Int}, idx::Int)
    s = 0
    while idx > 0
        s += bit[idx]
        idx -= idx & (-idx)
    end
    return s
end
"""
Calcola la differenza tra cumulativa 2D in O(M log M) e gaussiana usando Sweep-line e Fenwick Tree.
"""
function calculate_delta_cumulative_optimized_FenwickTree(df::DataFrame, N::Int)
    # Estrazione array con tipo forzato per performance
    raw_x::Vector{Float32} = Float32.(df.x)
    raw_y::Vector{Float32} = Float32.(df.y)

    len = length(raw_x)

    # Riscalamento
    sqrtN = Float32(sqrt(N))
    x = raw_x ./ sqrtN
    y = raw_y ./ sqrtN

    len = length(x)

    # 1. Compressione delle coordinate Y (necessaria per indicizzare il BIT)
    y_unique = sort(unique(y))
    y_map = Dict{Float32, Int}(val => i for (i, val) in enumerate(y_unique))
    max_y_rank = length(y_unique)

    # 2. Preparazione punti per Sweep-line
    # Salviamo l'indice originale per restituire i risultati nello stesso ordine
    points = [(x[i], y[i], i) for i in 1:len]
    # Ordiniamo per X, poi per Y per gestire correttamente i duplicati
    sort!(points, by = p -> (p[1], p[2]))

    bit = zeros(Int, max_y_rank)
    delta_cum_sup = 0.0
    sigma         = 0.0

    p = Progress(len; dt=0.5, desc="Calcolo Sup Differenza Cumulative: ")

    # 3. Sweep-line
    i = 1
    while i <= len
        # Gestiamo gruppi di punti con la stessa X per evitare errori di conteggio
        j = i
        while j <= len && points[j][1] == points[i][1]
            # Aggiungiamo il punto al BIT usando il rank della sua coordinata Y
            rank_y = y_map[points[j][2]]
            bit_update!(bit, rank_y, 1)
            j += 1
        end

        # Ora che tutti i punti con X <= points[i].x sono nel BIT, interroghiamo
        for k in i:(j-1)
            rank_y = y_map[points[k][2]]
            orig_idx = points[k][3]
            # Conta quanti punti hanno Y_rank <= rank_y (ovvero Y <= py)
            cont = bit_query(bit, rank_y)
            cum  = cont / len
            xi, yi = points[k]
            delta_cum = abs( cum - (1.0 + erf(xi)) * (1.0 + erf(yi)) / 4.0 )

            if delta_cum_sup < delta_cum
                delta_cum_sup = delta_cum
                # Calcolo della deviazione standard
                sigma = sqrt( (cum * (1.0 - cum)) / len )
            end

            next!(p)
        end
        i = j
    end

	# restituiamo il sup con la relativa incertezza statistica
    return (delta_cum_sup, sigma)
end

# Funzione main
function main()
    # Preparazione cartelle
    mkpath("./data")
    mkpath("./plots")

    results_s = Tuple{Float32, Float32}[]
    valid_N_s = Int[]
    files_s   = []

    for N in N_VALUES
        # Simulazione Scalata
        samples = floor(Int, SCALING_FACTOR * (N^2))
        s_file = run_drunk_man(N, samples, "scaling")
        push!(files_s, s_file)
    end

    for (N, s_file) in zip(N_VALUES, files_s)
        @printf("Analisi dati -> N=%d...\n", N)
        if !isnothing(s_file)
            df_s = load_data_safe(s_file)
            if !isnothing(df_s)
                res = calculate_delta_cumulative_optimized_FenwickTree(df_s, N)
                push!(results_s, res)
                push!(valid_N_s, N)
            end
            df_s = nothing
            GC.gc()
        end
    end

    # --- PLOT FINALE ---
    if !isempty(results_s)
        x = valid_N_s
        y = [r[1] for r in results_s]
        sy = [r[2] for r in results_s]

        whgs = 1.0 ./ sy.^2

        # fit
        @. model(xx,p) = p[1] * xx^p[2] + p[3]
        p0 = [ mean( x .* y ), -1.0, 0.0 ]

        fit   = curve_fit(model, x, y, whgs, p0)
        p_fit = coef(fit)
        err   = stderror(fit)
        cov_m = vcov(fit)

        chi2  = sum( whgs.*( y .- model(x,p_fit) ).^2 ) / ( length(x) - length(p0) )

        println("\n" * "="^30)
        println("RISULTATI DEL FIT: y = a * N^b + c")
        @printf("a: %.6f ± %.6f\n", p_fit[1], err[1])
        @printf("b: %.6f ± %.6f\n", p_fit[2], err[2])
        @printf("c: %.6f ± %.6f\n", p_fit[3], err[3])
        println("-"^30)
        println("Matrice di Covarianza:")
        display(cov_m)
        println("Chi2 ridotto")
        @printf("chi2: %.6f\n", chi2)
        println("\n" * "="^30)

        open("./plots/results.txt", "w") do f
            write(f, "RISULTATI DEL FIT: y = a * N^b + c\n")
            @printf(f, "Parametri:\n")
            @printf(f, "a: %.10f +/- %.10f\n",   p_fit[1], err[1])
            @printf(f, "b: %.10f +/- %.10f\n",   p_fit[2], err[2])
            @printf(f, "c: %.10f +/- %.10f\n\n", p_fit[3], err[3])
            write(f, "Matrice di Covarianza:\n")
            # Scrittura formattata della matrice
            for row in eachrow(cov_m)
                write(f, join([@sprintf("%.10e", x) for x in row], "\t") * "\n")
            end
            @printf(f, "chi2: %.6f\n", chi2)
        end

        # Setup Plot con backend GR
        gr()

        x_fit = exp10.(range(log10(minimum(x)*0.8), stop=log10(maximum(x)/0.8), length=100))
        y_fit = model(x_fit, p_fit)

        p = plot(
            x, y,
            yerror = sy,
            xscale = :log10,
            yscale = :log10,
            seriestype = :scatter,
            title  = "Distanza del sup",
            xlabel = L"N",
            ylabel = L"D_{\textrm{sup}}",
            label  = "Dati simulati",
            legend = true,
            grid   = true,
            minorgrid = true,
            markerstrokewidth = 1,
            markersize = 2,
            dpi    = 300
        )
        plot!(
            p, x_fit, y_fit, 
            label = "Fit: a*N^b + c", 
            linestyle = :dash, 
            linecolor = :red, 
            linewidth = 2
        )

        savefig(p, "./plots/confronto_totale.svg")
        savefig(p, "./plots/confronto_totale.png")
        display(p)
        readline()
    end
end

# Esecuzione
main()

//==============================================================================
// ifacconf.typ 2023-11-17 Alexander Von Moll
// Template for IFAC meeting papers
//
// Adapted from ifacconf.tex by Juan a. de la Puente
//==============================================================================

#import "@preview/abiding-ifacconf:0.2.0": *
#import "@preview/physica:0.9.5": *

#show: ifacconf-rules
#show: ifacconf.with(
  title: [TODO TITOLO],
  authors: (
    (
      name: "M. Barbieri",
      email: "m.barbieri20@studenti.unipi.it",
      affiliation: 1,
    ),
    (
      name: "M. Leonardi",
      email: "TODO INSERIRE MAIL",
      affiliation: 1,
    ),
  ),
  affiliations: (
    (
      organization: "University of Pisa",
      address: [Largo Pontecorvo 3, I-56127 Pisa, Italy\ ],
    ),
  ),
  abstract: [
TODO: abstract
  ],
)

#let cal(it) = math.class("normal", box({
  show math.equation: set text(font: "Garamond-Math", stylistic-set: 3)
  $#math.cal(it)$
}) + h(0pt))

#let otimes={math.times.circle}
#set list(body-indent: 0.3em,indent: 0.1em,spacing: 0.5em)
#set enum(body-indent: 0.7em,indent: 0.1em,spacing: 0.5em)
#set math.cases(gap: 1em)
#set table(
  stroke: (x,y) => (
    x: none,
    top: if y == 0 or y == 1 {0.6pt},
    bottom: { 0.6pt },
  ),
  align: (x, y) => if y == 0 {center} else if x == 0 { right } else { left },
  row-gutter: (1.5pt,0pt),
  column-gutter: 0pt,
)
#show table.cell.where(y: 0): strong
#show figure.caption.where(kind: figure): (cont) => {
  block(
    inset: (x: 10pt, y: 0pt),
    outset: 0pt,
    {
    cont
    h(1fr)
    v(-10pt)
  })
}
#show figure.caption.where(kind: table): (cont) => {
  align(
    center,
    cont
  )
}
#show figure.where(kind: table): set figure(supplement: [Table])
#let pm={math.plus.minus}
#let simeq={math.tilde.eq}
#let boring_proof(proof) = {
  parbreak()
  box(baseline: -2pt, line(length: 5%, stroke: 0.3pt))
  h(1fr)
  text(size: 8pt)[Proof]
  h(1fr)
  box(baseline: -2pt, line(length: 80%, stroke: 0.3pt))
  v(-4pt)
  text(size: 8pt, proof)
  v(-5pt)
  line(length: 100%, stroke: 0.3pt)
  v(-2pt)
}
#let tableFromCSV(filename, column-gutter: auto, cell-inset: auto, ..args) = {
  let csvfile = csv("example.csv")
  let csvfile-data = csvfile.slice(1).map( row=>{
    row.map( cell=>{
      eval(cell, mode: "markup")
    })
  })

  set table.cell(inset: cell-inset, align: horizon)
  
  table(
      columns: csvfile.first().len(),
      column-gutter: column-gutter,
      table.header( ..csvfile.first().map( title => { eval(title, mode: "markup") } ) ),
      ..csvfile-data.flatten(),
      ..args
  )
}

= Introduction

#bibliography("refs.bib", style: "springer-basic", full: true)

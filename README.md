# LR
explore different techniques to generate LR(k) parsing code

# Methods

* Normal approach

  * very naive LR(1) parsing algorithm. use hardcoded lr(1) parsing code to interpret array-based table

* Automata simulated by GADT

  * Hardcoded GADT

  * Hardcoded optimized GADT

  * token information --> optional intermediate data structure like a GADT? --> use typed refunctionalization to generate mutually recursive functionals (optimized)
   
  * Generate optimized GADT using MetaOCaml (techinically impossible now)

* Stackless LR(1) parser
  
  * An improvement to [Derivation of a Typed Functional LR Parser](http://www.cs.ox.ac.uk/ralf.hinze/publications/TypedLR.pdf)  
    Stack is implicitly represented as continuation function. Since no explicit
    stack data structure is present, it is possible to use MetaOCaml to generate
    parser.

# How-to

Take a canonical example, Grammar 4.1 in _Aho_.

1. manually go over all algorithms on paper, get very familar with LR(1) parsing process. How optimization works?

2. write naive LR(1) parser on computer

3. try different black technologies
  


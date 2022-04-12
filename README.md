
<img src="/uploads/3b37882713af00af40ea54104817261a/dust_logo.png" width="100">

This is DUST, a flexible solution for aerodynamic simulation of complex 
configurations.

Copyright &copy; 2018-2022 Politecnico di Milano
                          with support from A^3 from Airbus

## License

Please see the [license guidelines](license.md)

## Overview

DUST comprises a solver, a preprocessor and a post processor.

The preprocessor accepts meshes in CGNS format or in simple point-connectivity
definition, or builds the geometry from parametric definitions.

The whole geometry generated by the preprocessor, alongside the definition
of reference frames and their motion is the input of the solver, that 
calculates the solution and generates the results.

The results are then employed by the postprocessor which elaborates the data
according to the user requests.

## Documentation

In the doc folder can be found a **[quick_start.pdf](doc/quick_start.pdf)** containing a description of the provided examples.

## Installation

Please see the [installation guidelines](install.md)

## Contributors

Please see the [contributiors](contributors.md)

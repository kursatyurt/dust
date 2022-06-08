# <img src="/uploads/3b37882713af00af40ea54104817261a/dust_logo.png" width="50"> DUST Aerodynamic Solver 

<!-- <img src="/uploads/a9c9b0254c955cb0d5b681b6695feb66/Goland_miniatura_1_.PNG" width="200"> -->
<img src="/uploads/e47649c3db0892bc6bb09673607eabe2/complete_model_dark_web.png" width="700">



This is DUST, a flexible solution for aerodynamic simulation of complex 
configurations.

Copyright &copy; 2018-2022 Politecnico di Milano
                          with support from A^3 from Airbus


DUST comprises a solver, a preprocessor and a post processor.

```mermaid
graph LR;
  dust_pre --> dust --> dust_post;
```

The preprocessor accepts meshes in CGNS format or in simple point-connectivity
definition, or builds the geometry from parametric definitions.

The whole geometry generated by the preprocessor, alongside the definition
of reference frames and their motion is the input of the solver, that 
calculates the solution and generates the results.

The results are then employed by the postprocessor which elaborates the data
according to the user requests.

## Core Features

#### Flexible Geometry and Movement

Import custom surface meshes. Or build them parametrically. Assign them to a reference frame, and make it move. And rotors build themselves!

### Scalable Models 

Choose the fidelity level: from single dimensional lifting line to fully three dimensional objects choose the right model for the required fidelity, for every component, all in the same simulation. 

### Particles Wake

Choose the Fast Multipole optimized particle wake to simulate complex interactions among wakes and with solid bodies with exceptional robustness. 

### Designed for Performance 

Designed from scratch to deliver mid-fidelity aerodynamics analysis at workstation level, with no requirements for cluster level resources. 

### Transient Maneuver

<img src="/uploads/cf45d9be5bdb66582172fc14f9bbb6a6/XV15_Rolling_Maneuver.gif" alt="Vid" width="520px"/>

### Aeroelastic Simulation

<img src="/uploads/957eb38af65f103c39c712a6f2facc08/Goland_Wing_Flutter.gif" alt="Vid" width="520px"/>


## Documentation

In the doc folder can be found a **[quick_start.pdf](doc/quick_start.pdf)** containing a description of the provided examples and the more detailed **[DUST_user_manual.pdf](doc/DUST_user_manual.pdf)** which includes all DUST input keywords



## Installation

Please see the [installation guidelines](install.md) 


## Publications
<p>
<details>

  <summary markdown="span">Journal Papers</summary>

* A. Zanotti, A. Savino, M. Palazzi, M. Tugnoli, and V. Muscarello. <i>Assessment of a mid-fidelity numerical approach for the investigation of tiltrotor aerodynamics</i>. Applied Sciences, 11(8):3385, 2021. <a href="https://www.mdpi.com/2076-3417/11/8/3385"><b>[PDF]</b></a><br><br>

* M. Tugnoli, D. Montagnani, M. Syal, G Droandi, and Alex Zanotti. <i>Mid-fidelity approach to aerodynamic simulations of unconventional vtol aircraft configurations</i>. Aerospace Science and Technology, page 106804, 2021,doi.org/10.1016/j.ast.2021.106804. <a href="https://www.sciencedirect.com/science/article/abs/pii/S127096382100314X"><b>[PDF]</b></a><br><br>

* A. Savino, A. Cocco, A. Zanotti, M. Tugnoli, P. Masarati, and V. Muscarello. <i>Coupling Mid-Fidelity Aerodynamics and Multibody Dynamics for the Aeroelastic Analysis of Rotary-Wing Vehicles</i>. Energies, 14(21), 6979. <a href="https://www.mdpi.com/1996-1073/14/21/6979"><b>[PDF]</b></a><br><br>

</details>
</p>
<p>
<details>

  <summary markdown="span">Conference Papers</summary>

* D. Montagnani, M. Tugnoli, F. Fonte, A. Zanotti, G. Droandi, and M. Syal. <i>Mid-fidelity analysis of unsteady interactional aerodynamics of complex vtol configurations</i>. In 45th European Rotorcraft Forum, Warsaw, Poland, September 2019. <a href="https://core.ac.uk/download/pdf/237171689.pdf"><b>[PDF]</b></a><br><br>

* D. Montagnani, M. Tugnoli, A. Zanotti, M. Syal, and G. Droandi. <i>Analysis of the interactional aerodynamics of the vahana evtol using a medium fidelity open source tool</i>. In Proceedings of the VFS Aeromechanics for Advanced Vertical FlightTechnical Meeting, San Jose, CA, USA, January 21-23 2020. AHS International.

* A. Cocco, A. Savino, D. Montagnani, M. Tugnoli, F. Guerroni, M. Palazzi, A. Zanoni, A. Zanotti, V. Muscarello. <i>Simulation of tiltrotor maneuvers by a coupled multibody-mid fidelity aerodynamic solver<i/>. In: 46th European Rotorcraft Forum, 2020. <a href="https://re.public.polimi.it/retrieve/handle/11311/1146478/540222/COCCA02-20.pdf"><b>[PDF]</b></a><br><br>

* A Cocco, A Savino, A Zanotti, A Zanoni, P Masarati, and V Muscarello. <i>Coupled multibody-mid fidelity aerodynamic solver for tiltrotor aeroelastic simulation</i>. In 9th International Conference on Computational Methods for Coupled Problems in Science and Engineering, COUPLED PROBLEMS 2021, pages 1–12. CIMNE, 2021. <a href="https://re.public.polimi.it/retrieve/handle/11311/1177598/632671/COCCA01-21.pdf"><b>[PDF]</b></a><br><br>

* A. Zanotti, A. Savino, M. Palazzi, M. Tugnoli, and V. Muscarello. <i>Mid-Fidelity Numerical Approach to Tiltrotor Aerodynamics</i>. In 47th European Rotorcraft Forum, Glasgow, UK, September 2021. <a href="https://re.public.polimi.it/retrieve/handle/11311/1184736/655321/ZANOA05-21.pdf"><b>[PDF]</b></a><br><br>

* A. Savino, A. Cocco, A. Zanoni, A. Zanotti, and V. Muscarello. <i>A Coupled Multibody-Mid Fidelity Aerodynamic Tool for the Simulation of Tiltrotor Manoeuvres</i>. In 47th European Rotorcraft Forum, Glasgow, UK, September 2021. <a href="https://re.public.polimi.it/retrieve/handle/11311/1183864/653034/SAVIA01-21.pdf"><b>[PDF]</b></a><br><br>

* A. Savino, A. Cocco, A. Zanoni, A. De Gaspari, A. Zanotti, J. Cardoso, D. Carvalhais and V. Muscarello. <i>Design and Optimization of Innovative Tiltrotor Wing Control Surfaces Through Coupled Multibody-Mid-Fidelity Aerodynamics Simulations</i>. In the Vertical Flight Society’s 78th Annual Forum Technology Display, Ft. Worth, Texas, USA, May 2022. 


</details>
</p>

#### Cite Us!
<p>
<details>

  <summary markdown="span">Did you use DUST for your work? Cite us!</summary>

To acknowledge our work please cite the following paper:

* M. Tugnoli, D. Montagnani, M. Syal, G Droandi, and Alex Zanotti. <i>Mid-fidelity approach to aerodynamic simulations of unconventional vtol aircraft configurations</i>. Aerospace Science and Technology, page 106804, 2021,doi.org/10.1016/j.ast.2021.106804. <a href="https://www.sciencedirect.com/science/article/abs/pii/S127096382100314X"><b>[PDF]</b></a><br><br>

If you are using the aeroelastic version of DUST coupled to the multibody software [MBDyn](https://www.mbdyn.org/):

* A. Savino, A. Cocco, A. Zanotti, M. Tugnoli, P. Masarati, and V. Muscarello. <i>Coupling Mid-Fidelity Aerodynamics and Multibody Dynamics for the Aeroelastic Analysis of Rotary-Wing Vehicles</i>. Energies, 14(21), 6979. <a href="https://www.mdpi.com/1996-1073/14/21/6979"><b>[PDF]</b></a><br><br>

</details>
</p>

## Contributors

Please see the [contributiors](contributors.md)

## License

Please see the [license guidelines](license.md)

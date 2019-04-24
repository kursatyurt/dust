!./\\\\\\\\\\\...../\\\......./\\\..../\\\\\\\\\..../\\\\\\\\\\\\\. 
!.\/\\\///////\\\..\/\\\......\/\\\../\\\///////\\\.\//////\\\////..
!..\/\\\.....\//\\\.\/\\\......\/\\\.\//\\\....\///.......\/\\\......
!...\/\\\......\/\\\.\/\\\......\/\\\..\////\\.............\/\\\......
!....\/\\\......\/\\\.\/\\\......\/\\\.....\///\\...........\/\\\......
!.....\/\\\......\/\\\.\/\\\......\/\\\.......\///\\\........\/\\\......
!......\/\\\....../\\\..\//\\\...../\\\../\\\....\//\\\.......\/\\\......
!.......\/\\\\\\\\\\\/....\///\\\\\\\\/..\///\\\\\\\\\/........\/\\\......
!........\///////////........\////////......\/////////..........\///.......
!!=========================================================================
!!
!! Copyright (C) 2018-2019 Davide   Montagnani, 
!!                         Matteo   Tugnoli, 
!!                         Federico Fonte
!!
!! This file is part of DUST, an aerodynamic solver for complex
!! configurations.
!! 
!! Permission is hereby granted, free of charge, to any person
!! obtaining a copy of this software and associated documentation
!! files (the "Software"), to deal in the Software without
!! restriction, including without limitation the rights to use,
!! copy, modify, merge, publish, distribute, sublicense, and/or sell
!! copies of the Software, and to permit persons to whom the
!! Software is furnished to do so, subject to the following
!! conditions:
!! 
!! The above copyright notice and this permission notice shall be
!! included in all copies or substantial portions of the Software.
!! 
!! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
!! EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
!! OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
!! NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
!! HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
!! WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
!! FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
!! OTHER DEALINGS IN THE SOFTWARE.
!! 
!! Authors: 
!!          Federico Fonte             <federico.fonte@outlook.com>
!!          Davide Montagnani       <davide.montagnani@gmail.com>
!!          Matteo Tugnoli                <tugnoli.teo@gmail.com>
!!=========================================================================


!> Module to treat the assembly and solution of the linear system

module mod_linsys


use mod_param, only: &
  wp, nl, max_char_len, pi

use mod_sim_param, only: &
  t_sim_param

use mod_math, only: &
  cross

use mod_handling, only: &
  error, warning, info, printout, dust_time, t_realtime

use mod_geometry, only: &
  t_geo

!use mod_aero_elements, only: &
!  t_elem_p
use mod_aeroel, only: &
  c_elem, c_pot_elem, c_vort_elem, c_impl_elem, c_expl_elem, &
  t_elem_p, t_pot_elem_p, t_vort_elem_p, t_impl_elem_p, t_expl_elem_p

use mod_surfpan, only: &
  t_surfpan

use mod_linsys_vars, only: t_linsys

!use mod_wake_pan, only: t_wake_panels

!use mod_wake_ring, only: t_wake_rings

use mod_wake, only: t_wake
!----------------------------------------------------------------------

implicit none

public :: initialize_linsys, assemble_linsys, solve_linsys, &
          destroy_linsys , dump_linsys

private

character(len=*), parameter :: this_mod_name = 'mod_linsys'

!----------------------------------------------------------------------

contains

!----------------------------------------------------------------------

!> Initialize the linear system
!!
!! In the present subroutine all the relevant data for the solution 
!! of the linear system are allocated. 
!! Then the aerodinamic influence coefficients of the static part of
!! the geometry are calculated, as well as the contribution of such part
!! to the right hand side
!!
!! All the parts of the linear system generated by a moving geometry will
!! be calculated in \ref assemble_linsys at the beginning of each timestep
subroutine initialize_linsys(linsys, geo, elems, expl_elems, &
                             wake, sim_param ) ! uinf)
 type(t_linsys), intent(out), target :: linsys
 type(t_geo), intent(in) :: geo
 type(t_impl_elem_p), intent(inout) :: elems(:)
 type(t_expl_elem_p), intent(inout) :: expl_elems(:)
 !type(t_wake_panels), intent(inout) :: wake_elems
 !type(t_wake_rings), intent(inout) :: wake_rings
 type(t_wake), intent(inout) :: wake
 type(t_sim_param) :: sim_param 
 real(wp) :: uinf(3)
 real(wp) :: rhoinf , Pinf
 integer :: ie, ntot, info

 character(len=max_char_len) :: msg
 character(len=*), parameter :: this_sub_name = 'initialize_linsys'
 

  ! Free-stream conditions
  uinf   = sim_param%u_inf
  Pinf   = sim_param%P_inf
  rhoinf = sim_param%rho_inf
 
  linsys%rank = geo%nelem_impl
  linsys%nstatic = geo%nstatic_impl; linsys%nmoving = geo%nmoving_impl
  !linsys%n_ll = geo%nll
  !linsys%nstatic_ll = geo%nstatic_ll; linsys%nmoving_ll = geo%nmoving_ll
  !linsys%n_ad = geo%nad
  !linsys%nstatic_ad = geo%nstatic_ad; linsys%nmoving_ad = geo%nmoving_ad
  linsys%nstatic_expl = geo%nstatic_expl
  linsys%nmoving_expl = geo%nmoving_expl
  linsys%n_expl =  geo%nelem_expl
  
  ntot = linsys%rank

  !Allocate the vectors of the right size 
  allocate( linsys%A(linsys%rank, linsys%rank))
  allocate( linsys%L_static(linsys%nstatic, linsys%nstatic_expl))
 ! allocate( linsys%D_static(linsys%nstatic, linsys%nstatic_ad))
  allocate( linsys%b(linsys%rank) )
  allocate( linsys%P(linsys%rank) )
  !allocate( linsys%b_static(3,linsys%rank) )
  allocate( linsys%b_static(linsys%nstatic,linsys%nstatic) )
  allocate( linsys%res(linsys%rank) )
  allocate( linsys%res_expl(linsys%n_expl,2))
  linsys%b_static = 0.0_wp
  linsys%res_expl = 0.0_wp
 

  !! == Pressure
  !Set the number of surface panels
  linsys%n_sp = geo%nSurfPan
  linsys%nstatic_sp = geo%nstatic_SurfPan
  linsys%nmoving_sp = geo%nSurfPan - geo%nstatic_SurfPan
  !Allocate matrix and rhs for pressure integral equation
  allocate( linsys%idSurfPan(geo%nSurfPan) )
  linsys%idSurfPan    = geo%idSurfPan
  allocate( linsys%idSurfPanG2L(geo%nSurfPan) )
  linsys%idSurfPanG2L = geo%idSurfPanG2L
  allocate( linsys%A_pres(geo%nSurfPan,geo%nSurfPan) )
  linsys%A_pres = 0.0_wp
  allocate( linsys%b_pres(geo%nSurfPan) )
  linsys%b_pres = 0.0_wp
  allocate( linsys%P_pres(linsys%n_sp) )
  allocate( linsys%res_pres(geo%nSurfPan) )
  linsys%res_pres = 0.0_wp
  allocate( linsys%b_static_pres(geo%nstatic_SurfPan,geo%nstatic_SurfPan) ) 
  

  !Build the static part of the system, saving also the static part of the 
  ! rhs
  do ie = 1,linsys%nstatic

    !build one row
    call elems(ie)%p%build_row_static(elems, expl_elems, linsys, &
                                      uinf, ie, 1, linsys%nstatic)
  enddo
  
  !! == Pressure
  !copy the matrix before it gets corrected for the wake contribution
  linsys%A_pres = linsys%A( geo%idSurfPan , geo%idSurfPan )
  
  ! add the wake contribution
  do ie = 1,linsys%nstatic
    !call elems(ie)%p%add_wake((/wake_elems%pan_p, wake_rings%pan_p/), &
    !                wake_elems%gen_elems_id, linsys,uinf,ie,1,linsys%nstatic)
    call elems(ie)%p%add_wake((/wake%pan_p, wake%rin_p/), &
                    wake%pan_gen_elems_id, linsys,uinf,ie,1,linsys%nstatic)

    !link the solution into the elements
    elems(ie)%p%mag => linsys%res(ie)

  enddo

  !all the moving part will be assembled in \ref assemble_linsys, here
  !only the pointer to the solutions are associated
  do ie = linsys%nstatic+1,linsys%rank
    
    !link the solution into the elements
    elems(ie)%p%mag => linsys%res(ie)

  enddo

  !At the end link all the explicit elements to their (latest) results
  do ie = 1,linsys%n_expl
    expl_elems(ie)%p%mag => linsys%res_expl(ie,1) 
  enddo

  !! == Pressure
  linsys%b_static_pres = linsys%b_static( & 
         geo%idSurfPan(1:geo%nstatic_SurfPan), &
         geo%idSurfPan(1:geo%nstatic_SurfPan) )
  do ie = 1 , geo%nSurfpan
    select type( el => elems(geo%idSurfPan(ie))%p ) ; class is(t_surfpan)
      el%pres_sol => linsys%res_pres(ie) 
    end select
  end do

  !Now perform a one-time LU decomposition of the static part of the system
  if (linsys%nstatic .gt. 0)  then
   call dgetrf(linsys%nstatic,linsys%nstatic, &
           linsys%A(1:linsys%nstatic,1:linsys%nstatic),linsys%nstatic, &
           linsys%P(1:linsys%nstatic),info)
    if ( info .ne. 0 ) then
      write(msg,*) 'error while factorizing the static part of the linear &
                    &system, Lapack DGETRF error code ', info
      call error(this_sub_name, this_mod_name, trim(msg))
    end if
  endif

  !! == Pressure
  if (linsys%nstatic_sp .gt. 0)  then
   call dgetrf(linsys%nstatic_sp,linsys%nstatic_sp, &
           linsys%A_pres(1:linsys%nstatic_sp,1:linsys%nstatic_sp), &
           linsys%nstatic_sp, linsys%P_pres(1:linsys%nstatic_sp),info)
    if ( info .ne. 0 ) then
      write(msg,*) 'error while factorizing the static part of the linear &
                    &system for pressure, Lapack DGETRF error code ', info
      call error(this_sub_name, this_mod_name, trim(msg))
    end if
  endif


end subroutine initialize_linsys

!----------------------------------------------------------------------

!> Assemble the linear system before solving it
!!
!! The linear system must be re-assembled each timestep since some geometry
!! parts might be moving during the simulation.
!! 
!! First for all the equations for non moving parts only the influence of
!! the moving parts are calculated, leaving all the static part as was 
!! already calculated in \ref initialize_linsys
!! 
!! Then for the equations for moving parts all the row and rhs are calculated
subroutine assemble_linsys(linsys, geo, elems,  expl_elems, &
                           wake, sim_param ) ! uinf)
 type(t_linsys), intent(inout) :: linsys
 type(t_geo), intent(in) :: geo
 type(t_impl_elem_p), intent(in) :: elems(:)
 type(t_expl_elem_p), intent(in) :: expl_elems(:)
 !type(t_wake_panels), intent(in) ::  wake_elems
 !type(t_wake_rings), intent(in) ::  wake_rings
 type(t_wake), intent(in) ::  wake
!real(wp), intent(in) :: uinf(:)
 type(t_sim_param) :: sim_param 
 real(wp) :: uinf(3)
 real(wp) :: rhoinf , Pinf

 integer :: ie, nst, ntot 

 ! Free-stream conditions
 uinf   = sim_param%u_inf
 Pinf   = sim_param%P_inf
 rhoinf = sim_param%rho_inf

 nst = linsys%nstatic
 ntot = linsys%rank
 !!1) calculate the vortex induced velocity
 !$omp parallel do private(ie) schedule(dynamic,2)
 do ie =1,linsys%rank

   !call elems(ie)%p%get_vort_vel(wake_elems%end_vorts, uinf)
   !call elems(ie)%p%get_vort_vel(wake%end_vorts, uinf)
   call elems(ie)%p%get_vort_vel(wake%vort_p, uinf)

 enddo
 !$omp end parallel do

  !!2) Generate the matrix without the wake correction
  !First all the static ones (passing as start and end only the dynamic part)
!$omp parallel private(ie) firstprivate(nst, ntot)
!$omp do schedule(dynamic)
  do ie = 1,nst

    call elems(ie)%p%build_row(elems,linsys,uinf,ie,nst+1,ntot)

  enddo
!$omp end do nowait

  !Then all the dynamic ones (passing as start and end the whole system)
!$omp do
  do ie = nst+1,ntot

    call elems(ie)%p%build_row(elems,linsys,uinf,ie,1,ntot)

  enddo
!$omp end do
!$omp end parallel

  !!3) Copy the non modified dynamic part of the matrix into the pressure one
  linsys%A_pres(1:linsys%nstatic_sp,linsys%nstatic_sp+1:linsys%n_sp) = & 
    linsys%A( geo%idSurfPan(1:linsys%nstatic_sp) , &
              geo%idSurfPan(linsys%nstatic_sp+1:linsys%n_sp) )
  linsys%A_pres(linsys%nstatic_sp+1:linsys%n_sp,1:linsys%n_sp) = &
    linsys%A( geo%idSurfPan(linsys%nstatic_sp+1:linsys%n_sp) , &
              geo%idSurfPan(1:linsys%n_sp) )
   
   !!4) Correct the matrix with the wake contributions
  !First all the static ones (passing as start and end only the dynamic part)
!$omp parallel private(ie) firstprivate(nst, ntot)
!$omp do schedule(dynamic)
  do ie = 1,nst

    call elems(ie)%p%add_wake((/wake%pan_p, wake%rin_p/), wake%pan_gen_elems_id, linsys,uinf,ie,nst+1,ntot)

    call elems(ie)%p%add_expl(expl_elems, linsys,uinf,ie,linsys%nstatic_expl+1,linsys%n_expl)

  enddo
!$omp end do nowait

  !Then all the dynamic ones (passing as start and end the whole system)
!$omp do
  do ie = nst+1,ntot

    call elems(ie)%p%add_wake((/wake%pan_p, wake%rin_p/), wake%pan_gen_elems_id, linsys,uinf,ie,1,ntot)

    call elems(ie)%p%add_expl(expl_elems, linsys,uinf,ie,1,linsys%n_expl)

  enddo
!$omp end do
!$omp end parallel

end subroutine assemble_linsys

!----------------------------------------------------------------------

!> Solve the linear system
!!
!! Solve the linear system. The system is solved using an LU decomposition.
!! The static part of the system is stored already decomposed in LU
!! The dynamic part of the system has been updated during the timestep, and
!! a global LU factorization of the matrix must be completed. Finally the
!! factorized system is solved. 
subroutine solve_linsys(linsys)
 type(t_linsys), intent(inout) :: linsys

! real(wp) , allocatable :: A_tmp(:,:)
! integer, allocatable :: IPIV(:)
 integer              :: INFO   
 character(len=max_char_len) :: msg
 character(len=*), parameter :: this_sub_name = 'solve_linsys'
  
  ! Operations on the side band matrices: done only if the system is
  ! mixed static/dynamic and those matrices exists
  if (linsys%nstatic .gt. 0 .and. linsys%nmoving .gt.0) then

    !=>Create the upper-diagonal block Usd
    !Swap in place Asd to get PssAsd
    call dlaswp(linsys%nmoving, &
           linsys%A(1:linsys%nstatic,linsys%nstatic+1:linsys%rank), &
           linsys%nstatic,1,linsys%nstatic,linsys%P(1:linsys%nstatic),1)

    !Solve Lss Usd = Pss Asd to get Usd and put it in place of Asd
    call dtrsm('L','L','N','U',linsys%nstatic,linsys%nmoving,1.0d+0,   &
           linsys%A(1:linsys%nstatic,1:linsys%nstatic),linsys%nstatic, &
           linsys%A(1:linsys%nstatic,linsys%nstatic+1:linsys%rank),    &
           linsys%nstatic)
    
    !==>Solve the lower-diagoal block Lds
    !Solve Pdd-1 Lds Uss = Ads for Pdd-1 Lds and put it in place of Ads
    call dtrsm('R','U','N','N',linsys%nmoving,linsys%nstatic,1.0d+0,   &
           linsys%A(1:linsys%nstatic,1:linsys%nstatic),linsys%nstatic,  &
           linsys%A(linsys%nstatic+1:linsys%rank,1:linsys%nstatic),    &
           linsys%nmoving)

    !==>Modify the dynamic square block
    !Modify the square block from Add to Add - Pdd-1Lds Usd
    call dgemm('N','N',linsys%nmoving,linsys%nmoving,linsys%nstatic,-1.0d+0, &
           linsys%A(linsys%nstatic+1:linsys%rank,1:linsys%nstatic), &
           linsys%nmoving,&
           linsys%A(1:linsys%nstatic,linsys%nstatic+1:linsys%rank), &
           linsys%nstatic,1.0d+0,&
           linsys%A(linsys%nstatic+1:linsys%rank,linsys%nstatic+1:linsys%rank),&
           linsys%nmoving)

  endif

  ! If the system has a dynamic part, factorize such part
  if (linsys%nmoving .gt. 0) then

    !==>Factorize and put in place the square dynamic block
    call dgetrf(linsys%nmoving,linsys%nmoving, &
           linsys%A(linsys%nstatic+1:linsys%rank,linsys%nstatic+1:linsys%rank), &
           linsys%nmoving,linsys%P(linsys%nstatic+1:linsys%rank),info)
    if ( info .ne. 0 ) then
      write(msg,*) 'error while factorizing the dynamic  block of &
                   &the linear system, Lapack DGETRF error code ', info
      call error(this_sub_name, this_mod_name, trim(msg))
    endif

  endif
  
  ! If the system is mixed finish the operation on the band blocks
  if (linsys%nstatic .gt. 0 .and. linsys%nmoving .gt.0) then
  !==> Permute the lower mixed bloc
  call dlaswp(linsys%nstatic, &
         linsys%A(linsys%nstatic+1:linsys%rank,1:linsys%nstatic), &
         linsys%nmoving,1,linsys%nmoving,&
         linsys%P(linsys%nstatic+1:linsys%rank),1)
  endif

  !==> Fix the lower part of the permutation matrix to make it global
  linsys%P(linsys%nstatic+1:linsys%rank) = &
  linsys%P(linsys%nstatic+1:linsys%rank) + linsys%nstatic

  !==> Solve the factorized system
  linsys%res = linsys%b
  call dgetrs('N',linsys%rank,1,linsys%A,linsys%rank,linsys%P,linsys%res, &
         linsys%rank,info)
  if ( info .ne. 0 ) then
    write(msg,*) 'error while solving the factorized system &
      &Lapack DGETRS error code ', info
    call error(this_sub_name, this_mod_name, trim(msg))
  end if

end subroutine solve_linsys

!----------------------------------------------------------------------

!> Destructor function for the linear system
!!
!! The destruction of the linear system type simply relies on passing it 
!! to the subroutine with intent(out), which automatically destroys all the 
!! members of linsys
subroutine destroy_linsys(linsys)
 type(t_linsys), intent(out) :: linsys
 
 !Dummy operation to suppress warning
 linsys%rank = -1

end subroutine destroy_linsys

!----------------------------------------------------------------------

!> Dump the matrix and rhs of the linear system to file
!!
!! TODO: consider moving these functionalities to the i/o modules
subroutine dump_linsys(linsys , filen_A , filen_b )
 type(t_linsys), intent(in) :: linsys
 character(len=*) , intent(in) :: filen_A , filen_b

 integer :: fid
 integer :: i1 


 fid = 21
 open(unit=fid, file=trim(adjustl(filen_A)) )
 do i1 = 1 , size(linsys%A,1)
  write(fid,*) linsys%A(i1,:)
 end do
 close(fid)
 
 fid = 22
 open(unit=fid, file=trim(adjustl(filen_b)) )
 do i1 = 1 , size(linsys%b,1)
  write(fid,*) linsys%b(i1)
 end do
 close(fid)

end subroutine dump_linsys

!----------------------------------------------------------------------

end module mod_linsys

!!=====================================================================
!!
!! Copyright (C) 2018 Politecnico di Milano
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
!!          Federico Fonte             <federico.fonte@polimi.it>
!!          Davide Montagnani       <davide.montagnani@polimi.it>
!!          Matteo Tugnoli             <matteo.tugnoli@polimi.it>
!!=====================================================================


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
          destroy_linsys , dump_linsys, dump_linsys_pres, &
          solve_linsys_pressure

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

 integer :: ie, ntot
 

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
  !allocate( linsys%b_static(3,linsys%rank) )
  allocate( linsys%b_static(linsys%nstatic,linsys%nstatic) )
  allocate( linsys%res(linsys%rank) )
  allocate( linsys%res_expl(linsys%n_expl,2))
  linsys%b_static = 0.0_wp
  linsys%res_expl = 0.0_wp


  !Build the static part of the system, saving also the static part of the 
  ! rhs
  do ie = 1,linsys%nstatic

    !build one row
    call elems(ie)%p%build_row_static(elems, expl_elems, linsys, &
                                      uinf, ie, 1, linsys%nstatic)

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

  ! Pressure integral equation +++++++++++++++++++++++++++++++++++++++++
  !Allocate matrix and rhs for pressure integral equation
  allocate( linsys%idSurfPan(geo%nSurfPan) )           ; linsys%idSurfPan    = geo%idSurfPan
  allocate( linsys%idSurfPanG2L(geo%nSurfPan) )        ; linsys%idSurfPanG2L = geo%idSurfPanG2L
  allocate( linsys%A_pres(geo%nSurfPan,geo%nSurfPan) ) ; linsys%A_pres = 0.0_wp
  allocate( linsys%b_pres(geo%nSurfPan) )              ; linsys%b_pres = 0.0_wp
  allocate( linsys%b_matrix_pres_debug(geo%nSurfPan,geo%nSurfPan) ) ; linsys%b_matrix_pres_debug = 0.0_wp

  ! Pressure integral equation +++++++++++++++++++++++++++++++++++++++++
  allocate( linsys%b_static_pres(geo%nstatic_SurfPan,geo%nstatic_SurfPan) ) 
  linsys%b_static_pres = linsys%b_static( & 
         geo%idSurfPan(1:geo%nstatic_SurfPan), &
         geo%idSurfPan(1:geo%nstatic_SurfPan) )

  ! for DEBUG only ( TO BE DELETED )
  linsys%b_matrix_pres_debug( geo%idSurfPan(1:geo%nstatic_SurfPan), &
                              geo%idSurfPan(1:geo%nstatic_SurfPan) ) = &
             linsys%b_static( geo%idSurfPan(1:geo%nstatic_SurfPan), &
                              geo%idSurfPan(1:geo%nstatic_SurfPan) )

  ! Pressure integral equation +++++++++++++++++++++++++++++++++++++++++

! +++++++++++ !!!!!!!!! It should be useless here !!!!!!!!! ++++++++++ !
!                                                                      !
! Slicing in assemble_linsys() only                                    !
!                                                                      !
! +++++++++++ !!!!!!!!! It should be useless here !!!!!!!!! ++++++++++ !
! ! Slicing --------------------
! linsys%A_pres = linsys%A( geo%idSurfPan , geo%idSurfPan )
! ! Remove Kutta condtion ------
! do ie = 1 , geo%nSurfpan
!   select type( el => elems(geo%idSurfPan(ie))%p ) ; class is(t_surfpan)
!     call el%correct_pressure_kutta( &
!           (/wake%pan_p, wake%rin_p/), wake%pan_gen_elems_id, linsys,uinf,ie,1,ntot)
!   end select
! end do
! 
! ! rhs: ....
! linsys%b_pres = 4*pi * ( Pinf + 0.5_wp * rhoinf * norm2(uinf) ** 2.0_wp )
! write(*,*) ' H_inf = ' , &
!       Pinf + 0.5_wp * rhoinf * norm2(uinf) ** 2.0_wp 
! !!!!!!!!! It should be useless here !!!!!!!!!

  ! Pressure integral equation +++++++++++++++++++++++++++++++++++++++++

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
 real(wp) :: uinf(3) , dist(3) , dist2(3)
 real(wp) :: rhoinf , Pinf, pupd, mag
 real(wp) :: elcen(3)

 integer :: ie, nst, ntot 
 integer :: ip , iw , is , inext , p1 , p2
 integer :: ipp(4) , iww(4)

 ! Free-stream conditions
 uinf   = sim_param%u_inf
 Pinf   = sim_param%P_inf
 rhoinf = sim_param%rho_inf

 nst = linsys%nstatic
 ntot = linsys%rank
 !calculate the vortex induced velocity
 !$omp parallel do private(ie) schedule(dynamic,2)
 do ie =1,linsys%rank

   !call elems(ie)%p%get_vort_vel(wake_elems%end_vorts, uinf)
   !call elems(ie)%p%get_vort_vel(wake%end_vorts, uinf)
   call elems(ie)%p%get_vort_vel(wake%vort_p, uinf)

 enddo
 !$omp end parallel do

  !First all the static ones (passing as start and end only the dynamic part)
!$omp parallel private(ie) firstprivate(nst, ntot)
!$omp do schedule(dynamic)
  do ie = 1,nst

    call elems(ie)%p%build_row(elems,linsys,uinf,ie,nst+1,ntot)

    !call elems(ie)%p%add_wake((/wake_elems%pan_p, wake_rings%pan_p/), wake_elems%gen_elems_id, linsys,uinf,ie,nst+1,ntot)
    call elems(ie)%p%add_wake((/wake%pan_p, wake%rin_p/), wake%pan_gen_elems_id, linsys,uinf,ie,nst+1,ntot)

    call elems(ie)%p%add_expl(expl_elems, linsys,uinf,ie,linsys%nstatic_expl+1,linsys%n_expl)


  enddo
!$omp end do nowait

  !Then all the dynamic ones (passing as start and end the whole system)
!$omp do
  do ie = nst+1,ntot

    call elems(ie)%p%build_row(elems,linsys,uinf,ie,1,ntot)

    !call elems(ie)%p%add_wake((/wake_elems%pan_p, wake_rings%pan_p/), wake_elems%gen_elems_id, linsys,uinf,ie,1,ntot)
    call elems(ie)%p%add_wake((/wake%pan_p, wake%rin_p/), wake%pan_gen_elems_id, linsys,uinf,ie,1,ntot)

    call elems(ie)%p%add_expl(expl_elems, linsys,uinf,ie,1,linsys%n_expl)

  enddo
!$omp end do
!$omp end parallel

  ! Pressure integral equation +++++++++++++++++++++++++++++++++++++++++

  ! Slicing --------------------
  linsys%A_pres = linsys%A( geo%idSurfPan , geo%idSurfPan )
  ! Remove Kutta condtion ------
  do ie = 1 , geo%nSurfpan
    select type( el => elems(geo%idSurfPan(ie))%p ) ; class is(t_surfpan)
      call el%correct_pressure_kutta( &
            (/wake%pan_p, wake%rin_p/), wake%pan_gen_elems_id, linsys,uinf,ie,1,ntot)
    end select
  end do
  
  ! rhs: ....

  ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ !
  ! Assemble the RHS of the linear system for the Bernoulli polynomial     !
  ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ !
  ! RHS = B_infty +                                 (a) far field
  !       + \oint_{Sb} { G ( du/dt - ... ) } +      (b) time-dependent
  !       +  \int_{V } { DG . \omega x U } +        (c) rotational
  !       +  \int_{Sb} { viscous terms }            (d) viscous
   
  ! RHS assembled as the sum of:
  ! (b) time-dependent source contribution: computed and assembled in the
  !     %build_row routines above
  ! do nothing here
  ! (c) rotational effects (up to now, ignoring ring wakes)
!$omp parallel do private(ie, iw, dist, elcen) schedule(dynamic,32) 
  do ie = 1 , geo%nSurfpan
    elcen = elems( geo%idSurfpan(ie) )%p%cen
    ! (c.1) particles ( part_p )
    if ( allocated( wake%part_p ) ) then
      do iw = 1 , size( wake%part_p )
        if  ( .not. ( wake%part_p(iw)%p%free ) ) then

          dist = wake%part_p(iw)%p%cen - elcen
          linsys%b_pres(ie) = linsys%b_pres(ie) + & 
            sum( dist * cross( wake%part_p(iw)%p%dir , wake%part_p(iw)%p%vel ) ) * &
                 wake%part_p(iw)%p%mag / ( (sqrt(sum(dist**2)+sim_param%VortexRad**2))**3.0_wp ) 
! singular  >>>  wake%part_p(iw)%p%mag / ( norm2(dist)**3.0_wp ) 
! Rosenhead >>>  wake%part_p(iw)%p%mag / ( (sqrt(sum(dist**2)+sim_param%VortexRad**2))**3.0_wp ) 
                 !EXPERIMENTAL: adding vortex rosenhead regularization
        end if
      end do 
    end if
  enddo
!$omp end parallel do

!$omp parallel do private(ie, iw, dist, dist2, p1, p2, ipp, iww,ip, is, inext, elcen) schedule(dynamic, 64) 
  do ie = 1 , geo%nSurfpan
    elcen = elems( geo%idSurfpan(ie) )%p%cen
    ! (c.2) line elements ( end_vorts )
    do iw = 1 , wake%n_pan_stripes
      if( associated( wake%end_vorts(iw)%mag ) ) then
        dist  = wake%end_vorts(iw)%ver(:,1) - elcen 
        dist2 = wake%end_vorts(iw)%ver(:,2) - elcen
        linsys%b_pres(ie) = linsys%b_pres(ie) - &
          0.5_wp * wake%end_vorts(iw)%mag * sum( wake%end_vorts(iw)%edge_vec * &
               ( cross(dist , wake%end_vorts(iw)%ver_vel(:,1) ) /(norm2(dist )**3.0_wp) + &
                 cross(dist2, wake%end_vorts(iw)%ver_vel(:,2) ) /(norm2(dist2)**3.0_wp) ) )  
      end if
    end do
    ! (c.3) constant surface doublets = vortex rings ( wake_panels )
    do ip = 1 , wake%pan_wake_len
      do iw = 1 , wake%n_pan_stripes
 
        p1 = wake%i_start_points(1,iw) 
        p2 = wake%i_start_points(2,iw)
 
        ipp = (/ ip , ip , ip+1, ip+1 /)
        iww = (/ p1 , p2 , p2  , p1   /)
 
        do is = 1 , wake%wake_panels(iw,ip)%n_ver ! do is = 1 , 4 
          
          inext = mod(is,wake%wake_panels(iw,ip)%n_ver) + 1 
          dist  = wake%wake_panels(iw,ip)%ver(:,is   ) - elcen 
          dist2 = wake%wake_panels(iw,ip)%ver(:,inext) - elcen
          
          linsys%b_pres(ie) = linsys%b_pres(ie) - &
            0.5_wp * wake%wake_panels(iw,ip)%mag * sum( wake%wake_panels(iw,ip)%edge_vec(:,is) * &
                 ( cross(dist , wake%pan_w_vel(:,iww(is   ),ipp(is   )) ) /(norm2(dist )**3.0_wp) + &
                   cross(dist2, wake%pan_w_vel(:,iww(inext),ipp(inext)) ) /(norm2(dist2)**3.0_wp) ) )   
!           ! old ----
!           0.5_wp * wake%end_vorts(iw)%mag * sum( wake%wake_panels(iw2,iw)%edge_vec(:,is) * &
!                ( cross(dist , wake%wake_panels(iw2,iw)%ver_vel(:,is   ) ) /(norm2(dist )**3.0_wp) + &
!                  cross(dist2, wake%wake_panels(iw2,iw)%ver_vel(:,inext) ) /(norm2(dist2)**3.0_wp) ) )  
!                ( cross(dist , wake%pan_w_vel(:,iw2  , ) ) /(norm2(dist )**3.0_wp) + &
!                  cross(dist2, wake%pan_w_vel(:,iw2+1, ) ) /(norm2(dist2)**3.0_wp) ) )  
!           ! old ----
          
        end do 
      end do
    end do
    ! (c.4) rings from actuator disks
    ! TODO: ...

    ! (d) viscous effects
    ! TODO: to be implemented

  end do
!$omp end parallel do

  ! (a) far field contribution
  linsys%b_pres = linsys%b_pres + &
                    4*pi * ( Pinf + 0.5_wp * rhoinf * norm2(uinf) ** 2.0_wp ) ! H_inf
  ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ !
  ! END Assemble the RHS of the linear system for the Bernoulli polynomial !
  ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ !

  ! Pressure integral equation +++++++++++++++++++++++++++++++++++++++++



end subroutine assemble_linsys

!----------------------------------------------------------------------

!> Solve the linear system
!!
!! At the moment the linear system is solved directly by means of a call to 
!! a standard lapack solver.
subroutine solve_linsys(linsys)
 type(t_linsys), intent(inout) :: linsys

 real(wp) , allocatable :: A_tmp(:,:)
 integer, allocatable :: IPIV(:)
 integer              :: INFO   
 character(len=max_char_len) :: msg
 character(len=*), parameter :: this_sub_name = 'solve_linsys'
 !TODO: cleanup output vars and calls
 !real(KIND=8) :: elapsed_time ! time_ini , time_fin
 !integer :: count1 , count_rate1 , count_max1 
 !integer :: count2 , count_rate2 , count_max2 

  allocate(A_tmp(size(linsys%A,1),size(linsys%A,2)) ) ; A_tmp = linsys%A
  allocate(IPIV(linsys%rank))
 
  linsys%res = linsys%b

   
  !call system_clock(count1,count_rate1,count_max1)
  call dgesv(linsys%rank,1,A_tmp,linsys%rank,IPIV, &
             linsys%res ,linsys%rank,INFO) 
  !call system_clock(count2,count_rate2,count_max2)

  if ( INFO .ne. 0 ) then
    write(msg,*) 'error while solving linear system, Lapack DGESV error code ',&
                  INFO
    call error(this_sub_name, this_mod_name, trim(msg))
  end if

  deallocate(A_tmp,IPIV) 

end subroutine solve_linsys

!----------------------------------------------------------------------

!> Solve the linear system
!!
!! At the moment the linear system is solved directly by means of a call to 
!! a standard lapack solver.
subroutine solve_linsys_pressure(linsys,res)
 type(t_linsys), intent(inout) :: linsys
 real(wp) , allocatable, intent(inout) :: res(:)

 real(wp) , allocatable :: A_tmp(:,:)
 integer, allocatable :: IPIV(:)
 integer              :: INFO
 integer              :: ARNK
 character(len=max_char_len) :: msg
 character(len=*), parameter :: this_sub_name = 'solve_linsys_pressure'
 !TODO: cleanup output vars and calls
 !real(KIND=8) :: elapsed_time ! time_ini , time_fin
 !integer :: count1 , count_rate1 , count_max1 
 !integer :: count2 , count_rate2 , count_max2 

  ARNK = size(linsys%A_pres,1)
  if ( size(linsys%A_pres,2) .ne. ARNK ) then
    write(msg,*) ' matrix of the pressure integral equation A_pres is not square'
    call error(this_sub_name, this_mod_name, trim(msg))
  end if

  allocate(A_tmp(ARNK,ARNK) ) ; A_tmp = linsys%A_pres
  allocate(IPIV(ARNK))

  if (.not. allocated(res)) allocate(res(ARNK)) 
  res = linsys%b_pres 

  !call system_clock(count1,count_rate1,count_max1)
  call dgesv(ARNK,1,A_tmp,ARNK,IPIV, &
             res ,ARNK,INFO) 
  !call system_clock(count2,count_rate2,count_max2)

  if ( INFO .ne. 0 ) then
    write(msg,*) 'error while solving linear system, Lapack DGESV error code ',&
                  INFO
    call error(this_sub_name, this_mod_name, trim(msg))
  end if

  deallocate(A_tmp,IPIV) 

end subroutine solve_linsys_pressure



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

!> Dump the matrix and rhs of the linear system to file
!!
!! TODO: consider moving these functionalities to the i/o modules
subroutine dump_linsys_pres(linsys , filen_A , filen_b , filen_b_debug )
 type(t_linsys), intent(in) :: linsys
 character(len=*) , intent(in) :: filen_A , filen_b
 character(len=*) , optional , intent(in) :: filen_b_debug

 integer :: fid
 integer :: i1 


 fid = 23
 open(unit=fid, file=trim(adjustl(filen_A)) )
 do i1 = 1 , size(linsys%A_pres,1)
  write(fid,*) linsys%A_pres(i1,:)
 end do
 close(fid)
 
 fid = 24
 open(unit=fid, file=trim(adjustl(filen_b)) )
 do i1 = 1 , size(linsys%b_pres,1)
  write(fid,*) linsys%b_pres(i1)
 end do
 close(fid)

 if ( present( filen_b_debug ) ) then
   fid = 24
   open(unit=fid, file=trim(adjustl(filen_b_debug)) )
   do i1 = 1 , size(linsys%b_matrix_pres_debug,1)
    write(fid,*) linsys%b_matrix_pres_debug(i1,:)
   end do
   close(fid)
 end if

end subroutine dump_linsys_pres

!----------------------------------------------------------------------

end module mod_linsys

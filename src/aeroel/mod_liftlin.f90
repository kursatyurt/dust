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

!> Module containing the specific subroutines for the lifting line
!! type of aerodynamic elements
module mod_liftlin

use mod_param, only: &
  wp, pi, max_char_len, prev_tri, next_tri, prev_qua, next_qua

use mod_handling, only: &
  error, printout

use mod_doublet, only: &
  potential_calc_doublet , &
  velocity_calc_doublet

use mod_linsys_vars, only: &
  t_linsys

use mod_sim_param, only: &
  t_sim_param

use mod_math, only: &
  cross

use mod_c81, only: &
  t_aero_tab, interp_aero_coeff

!use mod_aero_elements, only: &
!  c_elem, t_elem_p

use mod_aeroel, only: &
  c_elem, c_pot_elem, c_vort_elem, c_impl_elem, c_expl_elem, &
  t_elem_p, t_pot_elem_p, t_vort_elem_p, t_impl_elem_p, t_expl_elem_p
!----------------------------------------------------------------------

implicit none

public :: t_liftlin, update_liftlin, solve_liftlin


!----------------------------------------------------------------------

type, extends(c_expl_elem) :: t_liftlin
  real(wp), allocatable :: tang_cen(:)
  real(wp), allocatable :: bnorm_cen(:)
  real(wp)              :: csi_cen
  integer               :: i_airfoil(2)
  real(wp)              :: chord
contains

  procedure, pass(this) :: compute_pot      => compute_pot_liftlin
  procedure, pass(this) :: compute_vel      => compute_vel_liftlin
  procedure, pass(this) :: compute_psi      => compute_psi_liftlin
  procedure, pass(this) :: compute_pres     => compute_pres_liftlin
  procedure, pass(this) :: compute_dforce   => compute_dforce_liftlin
  procedure, pass(this) :: calc_geo_data    => calc_geo_data_liftlin
end type

character(len=*), parameter :: this_mod_name='mod_vortring'

integer :: it=0

!----------------------------------------------------------------------
contains
!----------------------------------------------------------------------

!> Compute the potential due to a lifting line
!!
!! this subroutine employs doublets  to calculate
!! the AIC of a lifting line on a surface panel, adding the contribution
!! to an equation for the potential.
subroutine compute_pot_liftlin (this, A, b, pos,i,j)
 class(t_liftlin), intent(inout) :: this
 real(wp), intent(out) :: A
 real(wp), intent(out) :: b
 real(wp), intent(in) :: pos(:)
 integer , intent(in) :: i,j

 real(wp) :: dou

  if ( i .ne. j ) then
    call potential_calc_doublet(this, dou, pos)
  else
!   AIC (doublets) = 0.0   -> dou = 0
    dou = -2.0_wp*pi
  end if

  A = -dou

  b=0.0_wp

end subroutine compute_pot_liftlin

!----------------------------------------------------------------------

!> Compute the velocity due to a lifting line
!!
!! This subroutine employs doublets basic subroutines to calculate
!! the AIC coefficients of a lifting line to a vortex ring, adding
!! the contribution to an equation for the velocity
subroutine compute_psi_liftlin (this, A, b, pos, nor, i, j )
 class(t_liftlin), intent(inout) :: this
 real(wp), intent(out) :: A
 real(wp), intent(out) :: b
 real(wp), intent(in) :: pos(:)
 real(wp), intent(in) :: nor(:)
 integer , intent(in) :: i , j

 real(wp) :: vdou(3)

  call velocity_calc_doublet(this, vdou, pos)

  A = sum(vdou * nor)


  !  b = ... (from boundary conditions)
  !TODO: consider moving this outside
  if ( i .eq. j ) then
    b =  4.0_wp*pi
  else
    b = 0.0_wp
  end if

end subroutine compute_psi_liftlin

!----------------------------------------------------------------------

!> Compute the velocity induced by a lifting line in a prescribed position
!!
!! WARNING: the velocity calculated, to be consistent with the formulation of
!! the equations is multiplied by 4*pi, to obtain the actual velocity the
!! result of the present subroutine MUST be DIVIDED by 4*pi
subroutine compute_vel_liftlin (this, pos, uinf, vel)
 class(t_liftlin), intent(in) :: this
 real(wp), intent(in) :: pos(:)
 real(wp), intent(in) :: uinf(3)
 real(wp), intent(out) :: vel(3)

 real(wp) :: vdou(3)


  ! doublet ---
  call velocity_calc_doublet(this, vdou, pos)

  vel = vdou*this%mag


end subroutine compute_vel_liftlin

!----------------------------------------------------------------------

subroutine compute_cp_liftlin (this, elems, uinf)
 class(t_liftlin), intent(inout) :: this
 type(t_elem_p), intent(in) :: elems(:)
 real(wp), intent(in) :: uinf(:)

 character(len=*), parameter      :: this_sub_name='compute_cp_liftlin'

  call error(this_sub_name, this_mod_name, 'This was not supposed to &
  &happen, a team of professionals is underway to remove the evidence')

!! only steady loads: steady data from table: L -> gam -> p_equiv
!this%cp =   2.0_wp / norm2(uinf)**2.0_wp * &
!        norm2(uinf - this%ub) * this%dy / this%area * &
!             elems(this%id)%p%idou

end subroutine compute_cp_liftlin

!----------------------------------------------------------------------

!> The computation of the pressure in the lifting line is not meant to
!! happen, loads are retrieved from the tables
subroutine compute_pres_liftlin (this, sim_param)
 class(t_liftlin), intent(inout) :: this
 !type(t_elem_p), intent(in) :: elems(:)
 type(t_sim_param), intent(in) :: sim_param

 character(len=*), parameter      :: this_sub_name='compute_pres_liftlin'

  call error(this_sub_name, this_mod_name, 'This was not supposed to &
  &happen, a team of professionals is underway to remove the evidence')

!! only steady loads: steady data from table: L -> gam -> p_equiv
!this%cp =   2.0_wp / norm2(uinf)**2.0_wp * &
!        norm2(uinf - this%ub) * this%dy / this%area * &
!             elems(this%id)%p%idou

end subroutine compute_pres_liftlin

!----------------------------------------------------------------------

!> The computation of loads happens in solve_liftlin and not in
!! this subroutine, which is not used
subroutine compute_dforce_liftlin (this, sim_param)
 class(t_liftlin), intent(inout) :: this
 !type(t_elem_p), intent(in) :: elems(:)
 type(t_sim_param), intent(in) :: sim_param

 character(len=*), parameter      :: this_sub_name='compute_dforce_liftlin'

  call error(this_sub_name, this_mod_name, 'This was not supposed to &
  &happen, a team of professionals is underway to remove the evidence')

!! only steady loads: steady data from table: L -> gam -> p_equiv
!this%cp =   2.0_wp / norm2(uinf)**2.0_wp * &
!        norm2(uinf - this%ub) * this%dy / this%area * &
!             elems(this%id)%p%idou

end subroutine compute_dforce_liftlin

!----------------------------------------------------------------------

!> Update of the solution of the lifting line.
!!
!! Here the extrapolation of the lifting line solution is performed
subroutine update_liftlin(elems_ll, linsys)
 type(t_expl_elem_p), intent(inout) :: elems_ll(:)
 type(t_linsys), intent(inout) :: linsys

 real(wp), allocatable :: res_temp(:)

  it = it + 1

  !HERE extrapolate the solution before the linear system
  if (it .gt. 2) then
    allocate(res_temp(size(linsys%res_expl,1)))
    res_temp = linsys%res_expl(:,1)
    linsys%res_expl(:,1) = 2.0_wp*res_temp - linsys%res_expl(:,2)
    linsys%res_expl(:,2) = res_temp
    deallocate(res_temp)
  else
    linsys%res_expl(:,2) = linsys%res_expl(:,1)
  endif

end subroutine update_liftlin

!----------------------------------------------------------------------

!> Solve the lifting line, in an iterative way
!!
!! The lifting line solution is not obtained from the solution of the linear
!! system. It is fully explicit, but by being nonlinear requires an
!! iterative solution.
subroutine solve_liftlin(elems_ll, elems_tot, &
                         elems_impl, elems_ad, &
                         elems_wake, elems_vort, &
                         sim_param, airfoil_data)
 type(t_expl_elem_p), intent(inout) :: elems_ll(:)
 type(t_pot_elem_p),  intent(in)    :: elems_tot(:)
 type(t_impl_elem_p), intent(in)    :: elems_impl(:)
 type(t_expl_elem_p), intent(in)    :: elems_ad(:)
 type(t_pot_elem_p),  intent(in)    :: elems_wake(:)
 type(t_vort_elem_p), intent(in)    :: elems_vort(:)
 type(t_sim_param),   intent(in)    :: sim_param
 type(t_aero_tab),    intent(in)    :: airfoil_data(:)

 real(wp) :: uinf(3)
 integer  :: i_l, j, ic
 real(wp) :: vel(3), v(3), up(3)
 real(wp), allocatable :: vel_w(:,:)
 real(wp) :: unorm, alpha
 real(wp) :: cl
 real(wp), allocatable :: aero_coeff(:)
 real(wp), allocatable :: dou_temp(:)
 real(wp) :: damp=2.0_wp
 real(wp), parameter :: toll=1e-6_wp
 real(wp) :: diff
 ! mach and reynolds number for each el
 real(wp) :: mach , reynolds
 ! arrays used for force projection
 real(wp) , allocatable :: a_v(:)   ! size(elems_ll)
 real(wp) , allocatable :: c_m(:,:) ! size(elems_ll) , 3
 real(wp) , allocatable :: u_v(:)   ! size(elems_ll)
 character(len=max_char_len) :: msg

 real(wp) :: max_mag_ll

  uinf = sim_param%u_inf

  allocate(dou_temp(size(elems_ll)))
  allocate(vel_w(3,size(elems_ll))) 
  ! Initialisation
  vel_w(:,:) = 0.0_wp 

  !Compute the velocity from all the elements except for liftling elems
  ! and store it outside the loop, since it is constant
  do i_l = 1,size(elems_ll)
    do j = 1,size(elems_impl) ! body panels: liftlin, vortlat 
      call elems_impl(j)%p%compute_vel(elems_ll(i_l)%p%cen,uinf,v)
      vel_w(:,i_l) = vel_w(:,i_l) + v
    enddo
    do j = 1,size(elems_ad) ! actuator disks 
      call elems_ad(j)%p%compute_vel(elems_ll(i_l)%p%cen,uinf,v)
      vel_w(:,i_l) = vel_w(:,i_l) + v
    enddo
    do j = 1,size(elems_wake) ! wake panels
      call elems_wake(j)%p%compute_vel(elems_ll(i_l)%p%cen,uinf,v)
      vel_w(:,i_l) = vel_w(:,i_l) + v
    enddo
    do j = 1,size(elems_vort) ! wake vort
      call elems_vort(j)%p%compute_vel(elems_ll(i_l)%p%cen,uinf,v)
      vel_w(:,i_l) = vel_w(:,i_l) + v
    enddo
  enddo

  vel_w = vel_w/(4.0_wp*pi)

  allocate(a_v(size(elems_ll)  )) ; a_v = 0.0_wp
  allocate(c_m(size(elems_ll),3)) ; c_m = 0.0_wp
  allocate(u_v(size(elems_ll)  )) ; u_v = 0.0_wp

  ! Remove the "out-of-plane" component of the relative velocity:
  ! 2d-velocity to enter the airfoil look-up-tables
  do i_l=1,size(elems_ll)
   select type(el => elems_ll(i_l)%p)
   type is(t_liftlin)
     u_v(i_l) = norm2((uinf-el%ub) - &
         el%bnorm_cen*sum(el%bnorm_cen*(uinf-el%ub))) 
   end select
  end do

  !Calculate the induced velocity on the airfoil
  do ic = 1,100   !TODO: Refine this iterative process 
    diff = 0.0_wp
    max_mag_ll = 0.0_wp
    do i_l = 1,size(elems_ll)

      ! compute velocity
      vel = 0.0_wp
      do j = 1,size(elems_ll)
        call elems_tot(j)%p%compute_vel(elems_ll(i_l)%p%cen,uinf,v)
        vel = vel + v
      enddo

      select type(el => elems_ll(i_l)%p)
      type is(t_liftlin)
        vel = vel/(4.0_wp*pi) + uinf - el%ub +vel_w(:,i_l)
        !vel = uinf - el%ub
        up = vel-el%bnorm_cen*sum(el%bnorm_cen*vel)

        ! Compute reference velocity (includes the motion of the body)
        ! to use in LUT (.c81) of aerodynamic loads (2d airfoil)
        !TODO: test these two approximations
        unorm = u_v(i_l)      ! velocity w/o induced velocity
      ! unorm = norm2(up)     ! full velocity
       
        ! Angle of incidence (full velocity)
        alpha = atan2(sum(up*el%nor), sum(up*el%tang_cen))
        alpha = alpha * 180.0_wp/pi  ! .c81 tables defined with angles in [deg]

        ! compute local Reynolds and Mach numbers for the section
        ! needed to enter the LUT (.c81) of aerodynamic loads (2d airfoil)
        mach     = unorm / sim_param%a_inf      
        reynolds = sim_param%rho_inf * unorm * & 
                   el%chord / sim_param%mu_inf    

        call interp_aero_coeff ( airfoil_data,  el%csi_cen, el%i_airfoil, &
                      (/alpha, mach, reynolds/) , aero_coeff )
        cl = aero_coeff(1)   ! cl needed for the iterative process
       
        ! Compute the "equivalent" intensity of the vortex line 
        dou_temp(i_l) = - 0.5_wp * unorm * cl * el%chord
        diff = max(diff,abs(elems_ll(i_l)%p%mag-dou_temp(i_l)))

      end select

      c_m(i_l,:) = aero_coeff
      a_v(i_l)   = alpha * pi/180.0_wp

    enddo

    !TODO: while refining the iterative process, 
    ! move this hardcoded parameter in the input files
    damp = 5.0_wp

    do i_l = 1,size(elems_ll)
      elems_ll(i_l)%p%mag = ( dou_temp(i_l)+ damp*elems_ll(i_l)%p%mag )&
                             /(1.0_wp+damp)
      max_mag_ll = max(max_mag_ll,abs(elems_ll(i_l)%p%mag))
    enddo

!   if(diff .le. toll) exit
    if(diff/max_mag_ll .le. toll) exit

  enddo

  ! Loads computation ------------
  do i_l = 1,size(elems_ll)
   select type(el => elems_ll(i_l)%p)
   type is(t_liftlin)
    ! avg delta_p = \vec{F}.\vec{n} / A = ( L*cos(al)+D*sin(al) ) / A
    el%pres   = 0.5_wp * sim_param%rho_inf * u_v(i_l)**2.0_wp * &
               ( c_m(i_l,1) * cos(a_v(i_l)) +  c_m(i_l,2) * sin(a_v(i_l)) )
    ! elementary force = p*n + tangential contribution from L,D
    el%dforce = ( el%nor * el%pres + &
                  el%tang_cen * &
                  0.5_wp * sim_param%rho_inf * u_v(i_l)**2.0_wp * ( &
                 -c_m(i_l,1) * sin(a_v(i_l)) + c_m(i_l,2) * cos(a_v(i_l)) &
                 ) ) * el%area
    ! elementary moment = 0.5 * rho * v^2 * A * c * cm, 
    ! - around bnorm_cen (always? TODO: check)
    ! - referred to the ref.point of the elem,
    !   ( here, cen of the elem = cen of the liftlin (for liftlin elems) )
    el%dmom = 0.5_wp * sim_param%rho_inf * u_v(i_l)**2.0_wp * &
                   el%chord * el%area * c_m(i_l,3)
   end select
  end do

  if(sim_param%debug_level .ge. 3) then
    write(msg,*) 'iterations: ',ic; call printout(trim(msg))
    write(msg,*) 'diff',diff; call printout(trim(msg))
    write(msg,*) 'diff/max_mag_ll:',diff/max_mag_ll; call printout(trim(msg))
  endif

  deallocate(dou_temp, vel_w)
  deallocate(a_v,c_m,u_v)

end subroutine solve_liftlin

!----------------------------------------------------------------------

subroutine calc_geo_data_liftlin(this, vert)
 class(t_liftlin), intent(inout) :: this
 real(wp), intent(in) :: vert(:,:)

 integer :: is, nsides
 real(wp):: nor(3), tanl(3)

  this%ver = vert
  nsides = this%n_ver


  ! center, for the lifting line is the mid-point
  this%cen =  sum ( this%ver(:,1:2),2 ) / 2.0_wp

  ! unit normal and area, ll should always have 4 sides
  nor = cross( this%ver(:,3) - this%ver(:,1) , &
               this%ver(:,4) - this%ver(:,2)     )

  this%area = 0.5_wp * norm2(nor)
  this%nor = nor / norm2(nor)

  ! local tangent unit vector as in PANAIR
  tanl = 0.5_wp * ( this%ver(:,nsides) + this%ver(:,1) ) - this%cen

  this%tang(:,1) = tanl / norm2(tanl)
  this%tang(:,2) = cross( this%nor, this%tang(:,1)  )


  ! vector connecting two consecutive vertices:
  ! edge_vec(:,1) =  ver(:,2) - ver(:,1)
  ! ll should always have 4 sides
  do is = 1 , nsides
    this%edge_vec(:,is) = this%ver(:,next_qua(is)) - this%ver(:,is)
  end do

  ! edge: edge_len(:)
  do is = 1 , nsides
    this%edge_len(is) = norm2(this%edge_vec(:,is))
  end do

  ! unit vector
  do is = 1 , nSides
    this%edge_uni(:,is) = this%edge_vec(:,is) / this%edge_len(is)
  end do

  ! ll-specific fields
  this%tang_cen = this%edge_uni(:,2) - this%edge_uni(:,4)
  this%tang_cen = this%tang_cen / norm2(this%tang_cen)

  this%bnorm_cen = cross(this%tang_cen, this%nor)
  this%bnorm_cen = this%bnorm_cen / norm2(this%bnorm_cen)
  this%chord = sum(this%edge_len((/2,4/)))*0.5_wp

  !TODO: is it necessary to initialize it here?
  this%dforce = 0.0_wp
  this%dmom   = 0.0_wp


end subroutine calc_geo_data_liftlin
!----------------------------------------------------------------------

end module mod_liftlin

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
!! Copyright (C) 2018-2022 Politecnico di Milano,
!!                           with support from A^3 from Airbus
!!                    and  Davide   Montagnani,
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
!!          Alessandro Cocco
!!=========================================================================


!> Module containing the specific subroutines for the vortex lattice
!! type of aerodynamic elements
module mod_stripe

  use mod_handling, only: &
    internal_error

  use mod_doublet, only: &
    potential_calc_doublet , &
    velocity_calc_doublet  , &
    gradient_calc_doublet

  use mod_linsys_vars, only: &
    t_linsys

  use mod_sim_param, only: &
    sim_param

  use mod_param, only: &
    wp, pi, max_char_len, prev_tri, next_tri, prev_qua, next_qua

  use mod_math, only: &
    cross, dot, linear_interp

  use mod_aeroel, only: &
    c_elem, c_pot_elem, c_vort_elem, c_impl_elem, c_expl_elem, &
    t_elem_p, t_pot_elem_p, t_vort_elem_p, t_impl_elem_p, t_expl_elem_p

  use mod_c81, only: &
    t_aero_tab, interp_aero_coeff

  use mod_vortpart, only: &
    t_vortpart_p

  use mod_wind, only: &
    variable_wind
  !----------------------------------------------------------------------

  implicit none

  public :: t_stripe

  !----------------------------------------------------------------------

  type, extends(c_impl_elem) :: t_stripe

    !> Adim coodinates of the stripe center wrt span
    real(wp) :: csi_cen
    !> Profile data [start-end]
    integer  :: i_airfoil(2)  
    !> Panel array
    type(t_pot_elem_p), allocatable :: panels(:) 
    !> Collocation point
    real(wp) :: ctr_pt(3)
    !> Chord 
    real(wp) :: chord
    !> Velocity induced by corrected stripes  
    real(wp) :: vel(3) 
    !> Velocity induced by other elements 
    real(wp) :: vel_w(3)  
    !> Local tangent in the center of the stripe in chordwise 
    real(wp) :: tang_cen(3)
    !> Local tangent in the center of the stripe in spanwise 
    real(wp) :: bnorm_cen(3)
    !> Norm of stripe velocity
    real(wp) :: vel_2d
    !> Drag coefficient 
    real(wp) :: cd
    !> Lift coefficient (from c81)
    real(wp) :: cl_visc
    !> Induced AoA 
    real(wp) :: alpha_ind
    !> AoA to input c81
    real(wp) :: alpha
    !> AoA at previous time step (only for dynstall)
    real(wp) :: alpha_old 
    !> Isolated alpha 
    real(wp) :: alpha_isolated 
    real(wp) :: vel_2d_isolated
    real(wp) :: vel_outplane
    real(wp) :: vel_outplane_isolated
    real(wp) :: al_ctr_pt
    real(wp) :: aero_coeff(3) 
    !> Stripe 'curvature'
    real(wp) :: curv_ac 
    !> Sweep angle 
    real(wp) :: d_2pi_coslambda
  
  contains

    procedure, pass(this) :: correction_c81_vortlatt  => correction_c81_vortlatt
    procedure, pass(this) :: compute_vel              => compute_vel_stripe
    procedure, pass(this) :: compute_grad             => compute_grad_stripe
    procedure, pass(this) :: get_vel_ctr_pt           => get_vel_ctr_pt_stripe
    procedure, pass(this) :: calc_geo_data            => calc_geo_data_stripe
    procedure, pass(this) :: get_vel_ctr_pt_final     => get_vel_ctr_pt_final_stripe
    !> Dummy for intel workaround
    procedure, pass(this) :: build_row                => build_row_stripe
    procedure, pass(this) :: build_row_static         => build_row_static_stripe
    procedure, pass(this) :: add_wake                 => add_wake_stripe
    procedure, pass(this) :: add_expl                 => add_expl_stripe
    procedure, pass(this) :: compute_pot              => compute_pot_stripe
    procedure, pass(this) :: compute_psi              => compute_psi_stripe      
    procedure, pass(this) :: compute_pres             => compute_pres_dummy
    procedure, pass(this) :: compute_pres_stripe      => compute_pres_stripe
    procedure, pass(this) :: compute_dforce           => compute_dforce_dummy
    procedure, pass(this) :: get_vort_vel             => get_vort_vel_stripe
    procedure, pass(this) :: get_bernoulli_source     => get_bernoulli_source_stripe
    procedure, pass(this) :: compute_dforce_jukowski  => compute_dforce_jukowski_stripe

  end type

  character(len=*), parameter :: this_mod_name='mod_stripe'
  public 

  !----------------------------------------------------------------------
  contains

  subroutine correction_c81_vortlatt(this, airfoil_data, linsys, diff, it_vl, i_s)
    class(t_stripe),   intent(inout) :: this
    type(t_aero_tab),  intent(in)    :: airfoil_data(:)
    type(t_linsys),    intent(inout) :: linsys
    integer,           intent(in)    :: it_vl, i_s !> debug only

    real(wp)                         :: diff
    real(wp)                         :: mach, reynolds, wind(3)
    real(wp)                         :: alpha, alpha_2d, alcl0
    real(wp),    allocatable         :: al0(:)
    real(wp),    allocatable         :: aero_coeff(:)
    real(wp)                         :: up(3), unorm
    real(wp)                         :: dforce(3), mag_inv, mag_visc 
    integer                          :: i_c, n_pan, id_pan
    real(wp)                         :: cl_inv, cl_visc
    real(wp)                         :: rel_fct, rhs_diff    
    integer                          :: id_a, i_a
    integer                          :: imach, nmach
    real(wp)                         :: machend, mach1, mach2
    integer                          :: irey, nRe, i_Re
    real(wp)                         :: reyn1, reyn2, al0_Re
    real(wp)                         :: e_l(3), e_d(3), c_m(3)
    !> Dynamic stall
    real(wp)                         :: thicc = 0.12 !> get as input? 
                                        !(should be the last 2 digits of NACA profile)
    real(wp)                         :: alpha_ref, K1, dAlpha_dt
    real(wp)                         :: rad_break, rad_dyn, M1, M2, g1, g2, g2_max
  

    
    !> Total panel on stripe 
    n_pan = size(this%panels)
    
    !> Stipe total velocity 
    wind = variable_wind(this%cen, sim_param%time)

    this%vel_2d_isolated = norm2((wind-this%ub) - this%bnorm_cen*dot(this%bnorm_cen, (wind - this%ub)))
    
    this%vel_outplane_isolated = dot(this%bnorm_cen, (wind-this%ub))
    
    this%alpha_isolated = atan2(dot((wind-this%ub), this%nor), & 
                              dot((wind-this%ub), this%tang_cen))*180.0_wp/pi

    this%vel = this%vel + wind - this%ub + this%vel_w

    this%vel_outplane = dot(this%bnorm_cen,this%vel)
    
    ! "effective" velocity = proj. of vel in the n-t plane
    up =  this%nor*dot(this%nor,this%vel) + this%tang_cen*dot(this%tang_cen,this%vel)
    unorm = norm2(up)      ! velocity w/o induced velocity
    this%vel_2d = unorm

    mag_inv = 0.0_wp
    do i_c = 1, n_pan
      if ( i_c .gt. 1 ) then
        mag_inv = mag_inv + (this%panels(i_c)%p%mag - this%panels(i_c-1)%p%mag) 
      else
        mag_inv = mag_inv + this%panels(i_c)%p%mag
      end if
    end do 

    !> Local Mach number 
    mach = unorm / sim_param%a_inf
    
    !> Local Reynolds number 
    reynolds = sim_param%rho_inf * unorm * this%chord / sim_param%mu_inf
    
    ! Angle of incidence (full velocity) 
    alpha = atan2(dot(up, this%nor), dot(up,this%tang_cen)) 

    !> "2D correction" of the induced angle
    alpha_2d = mag_inv / ( pi * this%chord * unorm ) 

    alpha = (alpha - alpha_2d) * 180.0_wp/pi  

    !> Interpolation of the aerodynamic coefficents 
    call interp_aero_coeff ( airfoil_data,  this%csi_cen, this%i_airfoil , &
                        (/alpha, mach, reynolds/), aero_coeff )
  
    !> Aerodynamic coefficients from c81 table  
    c_m = aero_coeff
    this%cl_visc = aero_coeff(1)
    this%cd = aero_coeff(2)  
    
    cl_visc = this%cl_visc    
    cl_inv = -2.0_wp * mag_inv / (unorm*this%chord)    

    !deallocate(aero_coeff)   

    !> Update term rhs (absolute)
    rhs_diff = (cl_visc - cl_inv)

    !> Update tolerance  
    diff = abs(cl_visc - cl_inv)
    
    do i_c = 1, n_pan
      !> Take the id of the panel in the linsys 
      id_pan = this%panels(i_c)%p%id
      !> Update of the rhs 
      linsys%b(id_pan) =  (1 + rhs_diff)*linsys%b(id_pan)       
    end do 

    ! === Update AOAs and aerodynamic coefficients ===
    !> unit vector in the direction of the relative velocity (_d for drag)
    !  and in the direction of the lift (_l for lift)
    e_l = this%nor * cos(this%al_ctr_pt) - this%tang_cen*sin(this%al_ctr_pt )
    e_d = this%nor * sin(this%al_ctr_pt) + this%tang_cen*cos(this%al_ctr_pt )
    e_l = e_l/norm2(e_l)
    e_d = e_d/norm2(e_d)
    
    !> Force calculation on the stripe 
    dforce = 0.0_wp
    do i_c = 1, n_pan
      dforce = dforce + this%panels(i_c)%p%dforce
    end do
    
    !> Update aerodynamic coefficients and AOA
    c_m(1) = sum(dforce* e_l) / &
                (0.5_wp*sim_param%rho_inf*unorm ** 2.0_wp * this%area )
    c_m(2) = sum(dforce*e_d)/&
                (0.5_wp*sim_param%rho_inf*unorm ** 2.0_wp * this%area )
    
    this%alpha = this%al_ctr_pt * 180_wp/pi
    this%aero_coeff = c_m(:) 

  end subroutine correction_c81_vortlatt

  !----------------------------------------------------------------------
  !> Compute an approximate value of the induced velocity at 1/4 of chord
  ! of an element. This routine re-computes the contributions of the
  ! potential elements only:
  ! - body panels
  ! - wake panels
  ! ------------------------------------------------------------------- !
  ! This routine uses the value in the centre of the panels of:         !
  ! - the free-stream and the body velocity                             !
  ! - the rotational part of the velocity, collected in this%uvort      !
  ! ------------------------------------------------------------------- !

  subroutine get_vel_ctr_pt_stripe(this, elems, wake_elems, vort_elems)
    class(t_stripe),      intent(inout)    :: this
    type(t_pot_elem_p),   intent(in)       :: elems(:)
    type(t_pot_elem_p),   intent(in)       :: wake_elems(:)
    type(t_vort_elem_p),  intent(in)       :: vort_elems(:)
  
    real(wp) :: v(3), x0(3)
    integer :: j
  
    ! Initialisation to zero
    this%vel = 0.0_wp
    ! Control point at 1/2-fraction of the chord (with curvature)
    x0 = this%cen
    !=== Compute the velocity from all the elements ===
    do j = 1,size(wake_elems)  ! wake panels
      call wake_elems(j)%p%compute_vel(x0,v)
      this%vel_w = this%vel_w + v
    enddo

    do j = 1, size(elems) ! body elements that do not have correction 
      call elems(j)%p%compute_vel(x0,v)
      this%vel_w = this%vel_w + v
    enddo

    do j = 1,size(vort_elems) ! wake vorticity elements 
      call vort_elems(j)%p%compute_vel(x0,v)
      this%vel_w = this%vel_w + v
    enddo
  
    !> induced velocity on stripe center 
    this%vel_w = this%vel_w/(4.0_wp * pi)
  
  end subroutine get_vel_ctr_pt_stripe

  subroutine compute_vel_stripe(this, pos, vel) 
    class(t_stripe),    intent(in)    :: this
    real(wp),  intent(in)             :: pos(:)
    real(wp), intent(out)             :: vel(3) 
    real(wp)                          :: vdou(3), mag

    integer                           :: i_c, n_pan
    !> Total panel on stripe 
    n_pan = size(this%panels)

    call velocity_calc_doublet(this, vdou, pos)
    !> Calculate total mag coming from the stripe 
    
    mag = 0.0_wp
    do i_c = 1, n_pan
      if ( i_c .gt. 1 ) then
        mag = mag + ( this%panels(i_c)%p%mag - this%panels(i_c-1)%p%mag ) 
      else
        mag = mag + this%panels(i_c)%p%mag
      end if
    end do 

    vel = vdou*mag 
    vel = vel/(4.0_wp*pi)
    
  end subroutine compute_vel_stripe   

  subroutine get_vel_ctr_pt_final_stripe(this, elems, wake_elems, vort_elems)
    class(t_stripe),      intent(inout)    :: this
    type(t_pot_elem_p),   intent(in)      :: elems(:)
    type(t_pot_elem_p),   intent(in)      :: wake_elems(:)
    type(t_vort_elem_p),  intent(in)      :: vort_elems(:)

    real(wp) :: v(3), x0(3), wind(3), vel_ctr_pt(3)
    integer :: j
  
    ! Initialisation to zero
    vel_ctr_pt = 0.0_wp  
    ! Control point at leading edge 
    x0 = 0.5_wp*( this%ver(:,1) + this%ver(:,2) )
    
    !=== Compute the velocity from all the elements ===
    do j = 1,size(wake_elems)  ! wake panels
      call wake_elems(j)%p%compute_vel(x0, v)
      vel_ctr_pt = vel_ctr_pt + v
    enddo

    !do j = 1,size(vort_elems) ! wake vorticity elements 
    !  call vort_elems(j)%p%compute_vel(x0, v)
    !  vel_ctr_pt = vel_ctr_pt + v
    !enddo

    !do j = 1,size(elems) ! body elements
    !  call elems(j)%p%compute_vel(x0, v)
    !  vel_ctr_pt = vel_ctr_pt + v
    !enddo
  
    wind = variable_wind(x0, sim_param%time)

    vel_ctr_pt = vel_ctr_pt/(4.0_wp*pi) + wind -  this%ub

    this%al_ctr_pt = atan2(sum(vel_ctr_pt*this%nor    ) , &
                          sum(vel_ctr_pt*this%tang_cen) )
  
  end subroutine get_vel_ctr_pt_final_stripe


  subroutine compute_grad_stripe(this, pos, grad)
    class(t_stripe), intent(in) :: this
    real(wp), intent(in) :: pos(:)
    real(wp), intent(out) :: grad(3,3)
    
    real(wp) :: grad_dou(3,3)
    
    ! doublet ---
    call gradient_calc_doublet(this, grad_dou, pos)
    
    grad = grad_dou*this%mag
    
  end subroutine compute_grad_stripe


  subroutine calc_geo_data_stripe(this, vert)
    class(t_stripe), intent(inout) :: this
    real(wp), intent(in)           :: vert(:,:)

    integer                        :: n_pan, is
    real(wp)                       :: nor(3), tanl(3), cen(3)
    real(wp)                       :: cos_lambda 
  
    n_pan = size(this%panels)
  
    this%ver(:,1) = this%panels(1)%p%ver(:,1)
    this%ver(:,2) = this%panels(1)%p%ver(:,2)
    this%ver(:,3) = this%panels(n_pan)%p%ver(:,3)
    this%ver(:,4) = this%panels(n_pan)%p%ver(:,4)

    nor = cross(this%ver(:,3) - this%ver(:,1) , &
                this%ver(:,4) - this%ver(:,2) )
    
    !> Avoid numerical singularities when compiled in debug mode
    if (norm2(nor) .lt. 1e-16_wp) then 
      nor(3) = 1e-16_wp
    end if
  
    this%nor = nor / norm2(nor)
    
    !> mid-point between trailing edge 
    this%cen = sum (this%ver(:,1:2),2) / 2.0_wp
    
    cen  = sum(this%ver,2) / 4.0_wp
    !> local tangent unit vector as in PANAIR
    tanl =  0.5_wp *  ( this%ver(:,4) + this%ver(:,1) ) - cen 
    this%tang(:,1) = tanl / norm2(tanl)
    this%tang(:,2) = cross(this%nor, this%tang(:,1))
    
    do is = 1 , 4
      this%edge_vec(:,is) = this%ver(:,next_qua(is)) - this%ver(:,is)
    end do
  
    do is = 1 , 4
      this%edge_len(is) = norm2(this%edge_vec(:,is))
    end do
  
    !> unit vector
    do is = 1 , 4
      this%edge_uni(:,is) = this%edge_vec(:,is) / this%edge_len(is)
    end do 
  
    !> area  
    this%area = 0.0_wp 
    do is = 1, n_pan
      this%area = this%area + this%panels(is)%p%area 
    end do  
  
    ! this-specific fields
    this%tang_cen = this%edge_vec(:,2) - this%edge_vec(:,4)
    this%tang_cen = this%tang_cen / norm2(this%tang_cen)
  
    this%bnorm_cen = cross(this%tang_cen, this%nor)
    this%bnorm_cen = this%bnorm_cen / norm2(this%bnorm_cen)
    
    this%chord = sum(this%edge_len((/2,4/)))*0.5_wp

    !> sweep angle
    cos_lambda  = norm2(cross(this%tang_cen , -this%edge_uni(:,1)))
    
    !> control point at panel center 
    this%ctr_pt = this%cen + this%tang_cen * this%chord / 2.0_wp    

    !> 2 * pi * | x_CP - x{1/4*c} | * cos(lambda)
    this%d_2pi_coslambda = norm2( this%cen - this%ctr_pt ) * &
                            2.0_wp*pi*cos_lambda
    this%cen    = this%ctr_pt

    ! overwrite nor
    this%nor = cross( this%bnorm_cen , this%tang_cen )
    this%nor = this%nor / norm2(this%nor) 
  end subroutine calc_geo_data_stripe

  !------------------------------DUMMY FUNCTIONS-----------------------------

  subroutine build_row_stripe(this, elems, linsys, ie, ista, iend)
    class(t_stripe), intent(inout)   :: this
    type(t_impl_elem_p), intent(in)  :: elems(:)
    type(t_linsys), intent(inout)    :: linsys
    integer, intent(in)              :: ie
    integer, intent(in)              :: ista, iend

  end subroutine build_row_stripe

  subroutine build_row_static_stripe(this, elems, expl_elems, linsys, &
                                    ie, ista, iend)
      class(t_stripe), intent(inout) :: this
      type(t_impl_elem_p), intent(in)       :: elems(:)
      type(t_expl_elem_p), intent(in)       :: expl_elems(:)
      type(t_linsys), intent(inout)    :: linsys
      integer, intent(in)              :: ie
      integer, intent(in)              :: ista, iend

  end subroutine build_row_static_stripe
    
  subroutine add_expl_stripe(this, expl_elems, linsys, &
    ie, ista, iend)
    class(t_stripe), intent(inout) :: this
    type(t_expl_elem_p), intent(in)  :: expl_elems(:)
    type(t_linsys), intent(inout)    :: linsys
    integer, intent(in)              :: ie
    integer, intent(in)              :: ista
    integer, intent(in)              :: iend

  end subroutine add_expl_stripe

  subroutine add_wake_stripe(this, wake_elems, impl_wake_ind, linsys, &
    ie, ista, iend)
    class(t_stripe), intent(inout)  :: this
    type(t_pot_elem_p), intent(in)    :: wake_elems(:)
    integer, intent(in)               :: impl_wake_ind(:,:)
    type(t_linsys), intent(inout)     :: linsys
    integer, intent(in)               :: ie
    integer, intent(in)               :: ista
    integer, intent(in)               :: iend

  end subroutine add_wake_stripe

  subroutine compute_pot_stripe(this, A, b, pos,i,j)
    class(t_stripe), intent(inout) :: this
    real(wp), intent(out) :: A
    real(wp), intent(out) :: b
    real(wp), intent(in) :: pos(:)
    integer , intent(in) :: i,j

  end subroutine compute_pot_stripe

  subroutine compute_psi_stripe(this, A, b, pos, nor, i, j )
    class(t_stripe), intent(inout) :: this
    real(wp), intent(out) :: A
    real(wp), intent(out) :: b
    real(wp), intent(in) :: pos(:)
    real(wp), intent(in) :: nor(:)
    integer , intent(in) :: i , j
    
  end subroutine compute_psi_stripe 

  subroutine get_vort_vel_stripe(this, vort_elems)
    class(t_stripe), intent(inout)  :: this
    type(t_vort_elem_p), intent(in)    :: vort_elems(:)
  
  end subroutine

  subroutine compute_pres_stripe(this) 
    class(t_stripe), intent(inout) :: this
        
  end subroutine compute_pres_stripe
  
  !> Dummy version doing nothing
  subroutine compute_pres_dummy(this, R_g)
    class(t_stripe), intent(inout) :: this
    real(wp)         , intent(in)    :: R_g(3,3)
  
  end subroutine compute_pres_dummy
  
  
  !> Compute the elementary force on the on the actual element
  subroutine compute_dforce_stripe(this)
  class(t_stripe), intent(inout) :: this
  
  end subroutine compute_dforce_stripe
  
  !> Dummy version doing nothing
  subroutine compute_dforce_dummy(this)
    class(t_stripe), intent(inout) :: this
  
  end subroutine compute_dforce_dummy
  
  subroutine compute_dforce_jukowski_stripe(this)
    class(t_stripe), intent(inout) :: this

  end subroutine  compute_dforce_jukowski_stripe

  function get_bernoulli_source_stripe(this) result(source)
    class(t_stripe), intent(inout) :: this
    real(wp) :: source
  
    character(len=*), parameter :: this_sub_name = 'get_bernoulli_source_stripe'
  
    !this is just a dummy, should never be used
    source = 0.0_wp
    !and for this reason here is an internal error
    call internal_error(this_sub_name, this_mod_name, &
                        'getting bernoulli source from a stripe')
  
  end function
    
  !----------------------------------------------------------------------
    
  end module mod_stripe
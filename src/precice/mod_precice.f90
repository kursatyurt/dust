module mod_precice

! *** to do ***
!> update position of the TE, using the rotation of the LE
!> update velocity field, exploiting connectivity
!> update velocity field, including the contribution of the angular vel
!> update force    field, exploiting connectivity
! *** to do ***

use mod_param, only: &
    wp, pi

use mod_handling, only: &
    error

use mod_math, only: &
    cross

use mod_geometry, only: &
    t_geo

use mod_aeroel, only: &
    t_pot_elem_p

use mod_liftlin, only: &
    t_liftlin

implicit none

private

public :: t_precice

!> Parameters
integer, parameter :: precice_mcl = 50 ! precice_max_char_len

!> PreCICE mesh -------------------------------------------------
type t_precice_mesh
  character(len=precice_mcl) :: mesh_name
  integer                    :: mesh_id
  integer , allocatable      :: node_ids(:)
  real(wp), allocatable      :: nodes(:,:)
  integer                    :: nnodes
  integer                    :: ndim
  integer , allocatable      :: elem_ids(:)
end type t_precice_mesh

!> PreCICE field ------------------------------------------------
type :: t_precice_field
  integer :: fid
  character(len=precice_mcl) :: fname
  character(len=precice_mcl) :: fio    ! 'read'/'write'
  character(len=precice_mcl) :: ftype  ! 'scalar'/'vector'
  real(wp), allocatable :: fdata(:,:)  ! (1,nnodes)/(nd,nnodes)
  real(wp), allocatable :: cdata(:,:)  ! data for storing/reloading fields
end type t_precice_field

!> PreCICE type -------------------------------------------------
type :: t_precice

  !> PreCICE configuration
  character(len=precice_mcl) :: config_file_name
  character(len=precice_mcl) :: solver_name
  character(len=precice_mcl) :: mesh_name     ! *** to do *** just one mesh?
  integer :: comm_rank, comm_size

  !> PreCICE mesh
  type(t_precice_mesh) :: mesh

  !> PreCICE fields
  integer :: n_fields
  type(t_precice_field), allocatable :: fields(:)

  !> PreCICE variables
  real(wp) :: dt_precice
  integer  :: is_ongoing
  character(len=precice_mcl) :: write_initial_data, &
                                read_it_checkp, write_it_checkp

  contains

  procedure, pass(this) :: initialize
  procedure, pass(this) :: initialize_mesh
  procedure, pass(this) :: initialize_fields
  procedure, pass(this) :: update_force
  procedure, pass(this) :: update_elems

end type t_precice
!> --------------------------------------------------------------

contains

!----------------------------------------------------------------
!>
subroutine initialize(this)
  class(t_precice), intent(inout) :: this

  write(*,*) ' Using PreCICE '

  !> Default input for dust in a preCICE coupled simulation
  this % config_file_name = './../precice-config.xml'
  this % solver_name = 'dust'
  this %   mesh_name = 'dust_mesh'
  this % comm_rank = 0
  this % comm_size = 1

  !> Initialize PreCICE participant and mesh
  call precicef_create( this % solver_name, & 
                        this % config_file_name, &
                        this % comm_rank, &
                        this % comm_size )

  this % mesh % mesh_name = this % mesh_name
  call precicef_get_dims( this % mesh % ndim )
  call precicef_get_mesh_id( this % mesh % mesh_name, this % mesh % mesh_id )

  !> Initialize some preCICE variables
  this % write_initial_data(1:precice_mcl)='                                                  '
  this % read_it_checkp(    1:precice_mcl)='                                                  '
  this % write_it_checkp(   1:precice_mcl)='                                                  '

  call precicef_action_write_initial_data(this % write_initial_data)
  call precicef_action_read_iter_checkp(  this % read_it_checkp)
  call precicef_action_write_iter_checkp( this %write_it_checkp)

end subroutine initialize

!----------------------------------------------------------------
!> 
subroutine initialize_mesh( this, geo )
  class(t_precice), intent(inout) :: this
  type(t_geo)     , intent(in)    :: geo

  integer :: i, i_comp, n_comp
  integer :: dnnodes, nnodes

  !> TODO: add component field, that describe if the component
  ! participates to the coupling. So far, all the components 
  ! participate.
  logical :: comp_coupling = .true.

  n_comp = size(geo%components)

  !> Count n. of nodes ==========================================
  nnodes = 0
  do i_comp = 1, n_comp
    if ( comp_coupling ) then
      select case( trim(geo%components(i_comp)%comp_el_type) )
        case('l')
          !> Set PreCICE nodes with LE only! ***to do***
          dnnodes = size(geo%components(i_comp)%i_points) / 2
          !> Increment number of nodes
          nnodes = nnodes + dnnodes
      ! case('v')
      ! case('p')
        case default
      end select
    end if
  end do

  !> Allocate participant%mesh fields ===========================
  ! *** to do *** 
  ! dust may need two grids:
  ! - node-centered for reading position from MBDyn
  ! - cell-centered for writing force to MBDyn
  ! *** to do ***
  allocate(this%mesh%node_ids(nnodes)); this%mesh%node_ids = 0
  allocate(this%mesh%nodes( this%mesh%ndim, nnodes ))
  nnodes = 0
  do i_comp = 1, n_comp
    if ( comp_coupling ) then
      select case( trim(geo%components(i_comp)%comp_el_type) )
        case('l')
          
          dnnodes = size(geo%components(i_comp)%i_points) / 2
          !> Here in the local reference frame ! ***to do***
          this%mesh%nodes(:,nnodes+1:nnodes+dnnodes) = &
            geo%components(i_comp)%loc_points(:,1:2*dnnodes:2)
          nnodes = nnodes + dnnodes

      ! case('v')
      ! case('p')
        case default
      end select
    end if
  end do

  !> check ---
  write(*,*) ' PreCICE, mesh % nodes: '
  do i = 1 , nnodes
    write(*,*) this%mesh%nodes(:,i)
  end do

  !> Initialize mesh ============================================
  !> Nodes
  call precicef_set_vertices( this%mesh%mesh_id, nnodes,  &
                              this%mesh%nodes, this%mesh%node_ids )
  this%mesh%nnodes = nnodes

  !> Connectivity
  !> Edges
  ! ...
  !> Elements
  ! ...


end subroutine initialize_mesh

!----------------------------------------------------------------
!> 
subroutine initialize_fields( this )
  class(t_precice), intent(inout) :: this

  !> Expected fields
  integer, parameter :: n_max_fields = 6
  character(len=precice_mcl) :: field_list(n_max_fields)
  character(len=precice_mcl) :: type_list(n_max_fields)
  character(len=precice_mcl) :: io_list(n_max_fields)

  integer :: i, nf, hasdata

  !> Fields that can be exchanged through PreCICE. Add a field if needed
  field_list(1) = 'Position'       ; type_list(1) = 'vector'; io_list(1) = 'read' 
  field_list(2) = 'Velocity'       ; type_list(2) = 'vector'; io_list(2) = 'read' 
  field_list(3) = 'Rotation'       ; type_list(3) = 'vector'; io_list(3) = 'read' 
  field_list(4) = 'AngularVelocity'; type_list(4) = 'vector'; io_list(4) = 'read' 
  field_list(5) = 'Force'          ; type_list(5) = 'vector'; io_list(5) = 'write'
  field_list(6) = 'Moment'         ; type_list(6) = 'vector'; io_list(6) = 'write'

  !> Count n. of exchanged fields
  nf = 0
  do i = 1, n_max_fields
    call precicef_has_data( trim(field_list(i)), this%mesh%mesh_id, hasdata )
    if ( hasdata .eq. 1 ) nf = nf + 1
  end do

  allocate( this%fields( nf ) )
  nf = 0
  do i = 1, n_max_fields
    call precicef_has_data( trim(field_list(i)), this%mesh%mesh_id, hasdata )
    if ( hasdata .eq. 1 ) then
      nf = nf + 1
      this%fields(nf)%fname = trim(field_list(i))
      this%fields(nf)%fio   = trim(   io_list(i))
      this%fields(nf)%ftype = trim( type_list(i))
      call precicef_get_data_id( trim(this%fields(nf)%fname), &
                                 this%mesh%mesh_id, this%fields(nf)%fid )
      !> Allocate and initialize fields to zero *** to do *** where to write initial data?
      if ( trim(this%fields(nf)%ftype) .eq. 'scalar' ) then
        allocate( this%fields(nf)%fdata(1, this%mesh%nnodes) )
        this%fields(nf)%fdata = 0.0_wp
      else if ( trim(this%fields(nf)%ftype) .eq. 'vector' ) then
        allocate( this%fields(nf)%fdata( this%mesh%ndim, &
                                         this%mesh%nnodes) )
        this%fields(nf)%fdata = 0.0_wp
      end if
    end if
  end do

  !> Allocate cdata for storing/reloading data in implicit coupling
  ! and initialize it
  do i = 1, nf
    if ( trim(this%fields(i)%fio) .eq. 'write' ) then
      allocate( this%fields(i)%cdata( size(this%fields(i)%fdata,1), &
                                      size(this%fields(i)%fdata,2) ) )
      this%fields(i)%cdata = this%fields(i)%fdata
    end if
  end do


end subroutine initialize_fields

!----------------------------------------------------------------
!> Update force/moment fields
subroutine update_force( this, elems )
  class(t_precice)  , intent(inout) :: this
  type(t_pot_elem_p), intent(in)    :: elems(:)

  integer :: i, j

  !> From dust elems to PreCICE mesh
  ! *** to do *** build and exploit the connectivity preCICE-dust
  do j = 1, size(this%fields)
    if ( trim(this%fields(j)%fname) .eq. 'Force' ) then
       this%fields(j)%fdata = 0.0_wp   ! reset
      do i = 1, size(elems)
        this%fields(j)%fdata(:,i  ) = this%fields(j)%fdata(:,i  ) + 0.5_wp * elems(i)%p%dforce
        this%fields(j)%fdata(:,i+1) = this%fields(j)%fdata(:,i+1) + 0.5_wp * elems(i)%p%dforce
        ! this%fields(j)%fdata(3,i  ) = this%fields(j)%fdata(3,i  )
        ! this%fields(j)%fdata(3,i+1) = this%fields(j)%fdata(3,i+1)
      end do
    end if
  end do

 
end subroutine update_force

!----------------------------------------------------------------
!> Update force/moment fields
subroutine update_elems( this, geo, elems )
  class(t_precice)  , intent(inout) :: this
  type(t_geo)       , intent(inout) :: geo
  type(t_pot_elem_p), intent(inout) :: elems(:)
 
  integer :: i,j, i_comp
  real(wp) :: n_rot(3), chord(3), chord_rot(3), omega(3)
  real(wp) :: theta
  real(wp) :: eps = 1.0e-9_wp
  integer :: j_pos, j_vel, j_rot, j_ome

  ! Find rotation and angular velocity field id
  j_rot = 0; j_ome = 0
  do j = 1, size(this%fields)
    if ( trim(this%fields(j)%fname) .eq. 'Position' )       j_pos = j
    if ( trim(this%fields(j)%fname) .eq. 'Velocity' )       j_vel = j
    if ( trim(this%fields(j)%fname) .eq. 'Rotation' )       j_rot = j
    if ( trim(this%fields(j)%fname) .eq. 'AngularVelocity') j_ome = j
  end do


  !> Update elems
  ! *** to do *** build and exploit the connectivity preCICE-dust
  do i_comp = 1, size(geo%components)
    associate( comp => geo%components(i_comp) )

    if ( comp%coupling ) then
      !> Reset comp%el()%ub, vel_ctr_pt: these fields are the average value of the
      ! velocity of the neighboring points and they will be filled "by accumulation"
      do i = 1, size(comp%el)
        select type( el => comp%el(i) ); type is(t_liftlin)
          el%ub = 0.0_wp ;  el%vel_ctr_pt = 0.0_wp
        end select
      end do

    if ( comp%comp_el_type(1:1) .eq. 'l' ) then
      do i = 1, size(comp%i_points_precice)

        !> Position of LE and TE -----------------------------------------------
        !> Rotation matrix
        n_rot = this%fields(j_rot)%fdata(:, comp%i_points_precice(i))
        theta = norm2( n_rot )
        if ( theta .lt. eps ) then
          n_rot = (/ 1.0_wp, 0.0_wp, 0.0_wp /)
          theta = 0.0_wp
        else
          n_rot = n_rot / theta
        end if

        !> Position of the LE
        geo%points(:, comp%i_points( 2*i-1 ) ) = &
           this%fields(j_pos)%fdata(:, comp%i_points_precice( i ) )

        chord = comp%c_ref_p(:,i)
        chord_rot =  cos(theta) * chord + &
                     sin(theta) * cross( n_rot, chord ) + &
                   ( 1.0_wp - cos(theta) ) * sum( chord*n_rot ) * n_rot

        !> Position of the TE
        geo%points(:, comp%i_points( 2*i ) ) = &
           geo%points(:, comp%i_points( 2*i-1 ) ) + chord_rot

        !> Velocity of the LE
        geo%points_vel(:, comp%i_points( 2*i-1 ) ) = &
           this%fields(j_vel)%fdata(:, comp%i_points_precice( i ) )

        !> Velocity of the TE
        omega = 0.0_wp
        geo%points_vel(:, comp%i_points( 2*i ) ) = &
           this%fields(j_vel)%fdata(:, comp%i_points_precice( i ) ) + &
           cross( omega, chord_rot )

        !> Velocity of the control point on the LL ( accumulation ), vel_ctr_pt
        ! and velocity of the center of the QUAD el, ub
        ! These velocities are evaluated as the average of the points of the 
        ! elements, exploiting the implicit connectivity of the LL components
        ! *** to do *** for general elements, an explicit definition of the
        ! connectivity may be required
        if ( i .lt. size(comp%i_points_precice) ) then
          select type( el => comp%el(i) ); type is(t_liftlin)
           el%vel_ctr_pt = el%vel_ctr_pt + &
                          0.5_wp * geo%points_vel(:, comp%i_points( 2*i-1 ) )
           el%ub = el%ub + &
                  0.25_wp * ( geo%points_vel(:, comp%i_points( 2*i-1 ) ) + &
                              geo%points_vel(:, comp%i_points( 2*i   ) ) )
          end select
        end if
        if ( i .gt. 1 ) then
          select type( el => comp%el(i-1) ); type is(t_liftlin)
           el%vel_ctr_pt = el%vel_ctr_pt + &
                          0.5_wp * geo%points_vel(:, comp%i_points( 2*i-1 ) )
           el%ub = el%ub + &
                  0.25_wp * ( geo%points_vel(:, comp%i_points( 2*i-1 ) ) + &
                              geo%points_vel(:, comp%i_points( 2*i   ) ) )
          end select
        end if


      end do

    else ! not a lifting line elements -> Error *** to do ***
      call error('update_elems','mod_precice', &
                 ' So far, coupling w/ structural solver is implemented &
                  &for lifting lines only. Stop.'); stop
    end if

    end if ! if coupling

    end associate
  end do

end subroutine update_elems

!----------------------------------------------------------------

end module mod_precice

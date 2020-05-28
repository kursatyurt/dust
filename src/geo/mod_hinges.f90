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
!! Copyright (C) 2018-2020 Davide   Montagnani, 
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

!> Module for introducing hinges and rotating parts in a component
module mod_hinges

use mod_param, only: &
  wp, max_char_len

use mod_math, only: &
  cross

use mod_parse, only: &
  t_parse, getstr, getint, getreal, getrealarray, getlogical, getsuboption, &
  countoption, finalizeparameters

implicit none

public :: t_hinge, t_hinge_input, build_hinges, hinge_input_parser, &
          initialize_hinge_config

private

! ---------------------------------------------------------------
!> Hinge input data type
type :: t_hinge_input
  character(len=max_char_len) :: tag
  character(len=max_char_len) :: nodes_input
  real(wp) :: node1(3), node2(3)
  integer  :: n_nodes
  real(wp), allocatable :: rr(:,:)
  character(len=max_char_len) :: node_file
  real(wp) :: ref_dir(3)
  real(wp) :: offset
  character(len=max_char_len) :: rotation_input
  real(wp) :: rotation_amplitude
end type t_hinge_input

! ---------------------------------------------------------------
!> Hinge connectivity, meant for rigid rotation and bleding regions
type :: t_hinge_conn
  !> Local index of the nodes performing the desired motion
  integer, allocatable :: node_id(:)
  !> Surface node performing motion vs. hinge node connectivity
  integer, allocatable :: ind(:,:)
  !> Surface node performing motion vs. hinge node connectivity, weights
  ! for the weighted average of the motion
  integer, allocatable :: wei(:,:)
end type t_hinge_conn

! ---------------------------------------------------------------
!> Hinge node configurations: to be used in defining reference
! and actual configurations
type :: t_hinge_config

  !> Position of the first and last point of the hinge in the local
  ! reference frame of the component
  real(wp) :: rr0(3), rr1(3)
  !> Local coordinates of the hinge nodes
  real(wp), allocatable :: rr(:,:)

  !> Unit vectors of the hinge node reference frames
  ! User input in local reference frame, for reference configuration: h, v
  !    h,
  !    n = cross(v,h) , n = n/norm2(n)
  !    v = cross(h,n)
  !> h: rotation axis
  real(wp), allocatable :: h(:,:)
  !> v: zero direction (user inputs are overwritten, in order to 
  ! build ortonormal reference frames
  real(wp), allocatable :: v(:,:)
  !> n: normal direction
  real(wp), allocatable :: n(:,:)

end type t_hinge_config

!> Hinge type
type :: t_hinge

  !> Number of points for transferring the motion from the hinge to the
  ! surface, through a weighted average
  ! *** to do *** hardcoded, so far. Read as an input, with a default value,
  ! equal to 2 (or 1?)
  integer :: n_wei = 2

  !> Order of the norm used for computing distance-based weights
  ! *** to do *** hardcoded, so far. Read as an input, with a default value,
  ! equal to 1 (or 2?)
  integer :: w_order = 1

  !> Type: parametric, from_file
  character(len=max_char_len) :: nodes_input

  !> N.nodes of the hinge
  integer :: n_nodes

  !> Offset for avoiding irregular behavior
  real(wp) :: offset

  !> Offset for avoiding irregular behavior
  real(wp) :: ref_dir(3)

  !> Type: constant, function, coupling
  character(len=max_char_len) :: input_type

  !> Array of the rotation angle (read as an input, or from coupling nodes)
  real(wp), allocatable :: theta(:)

  !> Reference configuration
  type(t_hinge_config) :: ref
  !> Actual configuration
  type(t_hinge_config) :: act

  !> Connectivity for the rigid rotation motion of a ``control surface''
  type(t_hinge_conn) :: rot
  !> Connectivity of the blending region to avoid irregular behavior 
  ! with a ``control surface'' large rotation (blending region extends
  ! from -offset to offset qualitatively in the ref_dir of the hinge)
  type(t_hinge_conn) :: blen

  contains
 
  procedure, pass(this) :: build_connectivity
  procedure, pass(this) :: from_reference_to_actual_config

end type t_hinge

! ---------------------------------------------------------------

contains

! ---------------------------------------------------------------
!> Build hinge connectivity from component nodes rr, expressed in the
! local reference frame, and the hinge nodes.
! >
! >
! >
subroutine build_connectivity(this, loc_points)
  class(t_hinge), intent(inout) :: this
  real(wp),       intent(in)    :: loc_points(:,:)

  real(wp) :: hinge_width
  integer  :: nb, nh, ib
  real(wp), allocatable :: rrb(:,:), rrh(:,:)
  real(wp) :: Rot(3,3) = 0.0_wp

  integer , allocatable :: node_id(:), ind(:,:)
  real(wp), allocatable :: wei(:,:)

  integer :: nrot, nble

  !> N. of surfae and hinge nodes
  nb = size(loc_points,2)
  nh = this%n_nodes
 
  !> Coordinates in the hinge reference frame
  ! Rotation matrix, build with the local ortonormal ref.frame of 
  ! the first hinge node
  Rot(1,:) = this % ref % v(1,:)
  Rot(2,:) = this % ref % h(1,:)
  Rot(3,:) = this % ref % n(1,:)

  allocate( rrb(3,nb) );  allocate( rrh(3,nh) )
  do ib = 1, nb
    rrb(:,ib) = matmul( Rot, loc_points(:,ib) - this%ref%rr(:,1) )
  end do
  do ib = 1, nh
    rrh(:,ib) = matmul( Rot, this%ref%rr(:,ib) - this%ref%rr(:,1) )
  end do

  ! hinge width, measured in the hinge direction
  hinge_width = rrh(2,nh) - rrh(2,1) 

  !> Compute connectivity and weights
  ! Allocate auxiliary node_id(:), ind(:,:), wei(:,:) arrays
  allocate(node_id(            nb)); node_id = 0
  allocate(    ind(this%n_wei, nb));     ind = 0
  allocate(    wei(this%n_wei, nb));     wei = 0.0_wp

  nrot = 0; nble = 0
  ! Loop over all the surface points
  do ib = 1, nb

    if ( ( rrb(2,ib) .gt. 0.0_wp ) .and. ( rrb(2,ib) .lt. hinge_width ) ) then

      if ( rrb(1,ib) .lt. -this%offset ) then
        ! do nothing
      elseif ( rrb(1,ib) .gt. this%offset ) then ! rigid rotation
        nrot = nrot + 1

         
      else ! blending region
        nble = nble + 1

      end if

    end if

  end do

  !> Fill hinge object, with the connectivity and weight arrays
  ! ...

end subroutine build_connectivity

! ---------------------------------------------------------------
!> Compute actual configuration of the hinge nodes
subroutine from_reference_to_actual_config(this)
  class(t_hinge), intent(inout) :: this

  ! *** to do ***

end subroutine from_reference_to_actual_config

! ---------------------------------------------------------------
!> Build hinge configuration
! Used to build reference configuration in load_component(), and
! initialize actual configuration, as the reference configuration
subroutine initialize_hinge_config( h_config, hinge )
  type(t_hinge_config), intent(inout) :: h_config
  type(t_hinge)       , intent(inout) :: hinge

  real(wp) :: hv(3), vv(3), nv(3)
  integer :: i

  !> rr0, rr1 (useless?)
  h_config%rr0 = hinge%ref%rr(:,1)
  h_config%rr1 = hinge%ref%rr(:,hinge%n_nodes)
  hv = h_config%rr1 - h_config%rr0;  hv = hv / norm2(hv)
  vv = hinge%ref_dir / norm2(hinge%ref_dir)
  nv = cross( vv, hv ); nv = nv / norm2(nv)
  vv = cross( hv, nv ); vv = vv / norm2(vv)  ! useless normalization

  !> h, v, n
  allocate( h_config%h(3, hinge%n_nodes) )
  allocate( h_config%v(3, hinge%n_nodes) )
  allocate( h_config%n(3, hinge%n_nodes) )

  do i = 1, hinge%n_nodes

    h_config%h(:,i) = hv;  h_config%v(:,i) = vv;  h_config%n(:,i) = nv 

  end do

end subroutine initialize_hinge_config


! ---------------------------------------------------------------
!> build hinges_input, used in dust_pre for generating geometry input file
! for the solver
subroutine build_hinges( geo_prs, n_hinges, hinges )
  type(t_parse), intent(inout) :: geo_prs
  integer      , intent(in)    :: n_hinges
  type(t_hinge_input), allocatable, intent(inout) :: hinges(:)

  type(t_parse), pointer :: hinge_prs
  integer :: i, j


  if ( allocated(hinges) ) deallocate(hinges)
  allocate( hinges(n_hinges) )

  do i = 1, n_hinges

    !> De-associate, before reading next hinge
    hinge_prs => null()
    !> Open hinge sub-parser
    call getsuboption(geo_prs, 'Hinge', hinge_prs)

     hinges(i) % tag = getstr(hinge_prs, 'Hinge_Tag')
     hinges(i) % nodes_input = getstr(hinge_prs, 'Hinge_Nodes_Input')

     if ( trim(hinges(i) % nodes_input) .eq. 'parametric' ) then
       hinges(i) % node1 = getrealarray(hinge_prs, 'Node1', 3)
       hinges(i) % node2 = getrealarray(hinge_prs, 'Node2', 3)
       hinges(i) % n_nodes = getint(hinge_prs, 'N_Nodes')
       hinges(i) % node_file = 'hinge with parametric input. If you read this &
           &string, something probabily went wrong.'
       allocate( hinges(i)%rr( 3, hinges(i)%n_nodes ) )
       do j = 1, hinges(i)%n_nodes
         hinges(i) % rr(:,j) = hinges(i) % node1 + &
                             ( hinges(i) % node2 - hinges(i) % node1 ) * &
                             dble(j-1)/dble(hinges(i)%n_nodes-1)
       end do

     elseif ( trim(hinges(i) % nodes_input) .eq. 'from_file' ) then
       ! *** to do *** fill dummy node1, node2, n_nodes fields
       hinges(i) % node_file = getstr(hinge_prs,'Node_File')
       call read_hinge_nodes( hinges(i)%node_file, &
                              hinges(i)%n_nodes  , &
                              hinges(i)%rr )
     else
       ! *** to do *** use error message handling
       write(*,*) ' Wrong Hinge_Nodes_Input input. Stop '; stop
     end if

     hinges(i) % ref_dir = getrealarray(hinge_prs, 'Hinge_Ref_Dir', 3)
     hinges(i) % offset  = getreal(hinge_prs, 'Hinge_Offset')
     hinges(i) % rotation_input     = getstr(hinge_prs, 'Hinge_Rotation_Input')
     hinges(i) % rotation_amplitude = getreal(hinge_prs,'Hinge_Rotation_Amplitude')
      
     ! check ---
     write(*,*) ' Hinge id:', i
     write(*,*) ' _Tag        : ', trim(hinges(i)%tag)
     write(*,*) ' _Nodes_Input: ', trim(hinges(i)%nodes_input)
     ! check ---

  end do

end subroutine build_hinges

! ---------------------------------------------------------------
!> Read ascii file of hinge node coordinates, w/ input type from_file
!  Three-column ascii file is expected
subroutine read_hinge_nodes( filen, n_nodes, rr )
  character(len=max_char_len), intent(in)  :: filen
  integer                    , intent(out) :: n_nodes
  real(wp), allocatable      , intent(out) :: rr(:,:)

  integer :: i, io
  integer :: fid = 21

  if ( allocated(rr) ) deallocate(rr)

  n_nodes = 0;  io = 0

  !> Preliminary read for determining the n. of lines
  open(unit=fid, file=trim(filen))
  do while ( io .eq. 0 )
    read(fid,*,iostat=io) ! dummy
    n_nodes = n_nodes + 1
  end do
  close(fid) 

  !> Allocate and fill rr array
  allocate(rr(3,n_nodes))
  open(unit=fid, file=trim(filen))
  do i = 1, n_nodes
    read(fid,*) rr(:,i)
  end do
  close(fid) 


end subroutine read_hinge_nodes

! ---------------------------------------------------------------
!> Hinge input parser, called in mod_build_geo.f90 by dust_pre preprocessor
subroutine hinge_input_parser( geo_prs, hinge_prs )
  type(t_parse),          intent(inout) :: geo_prs
  type(t_parse), pointer, intent(inout) :: hinge_prs

  call geo_prs%CreateIntOption('n_hinges', &
              'N. of hinges and rotating parts (e.g. aileron) of the component', &
              '0') ! default: no hinges -> n_hinges = 0
  
  call geo_prs%CreateSubOption('Hinge', 'Parser for hinge input', &
               hinge_prs, multiple=.true. )

  call hinge_prs%CreateStringOption('Hinge_Tag','Name of the hinge')
  call hinge_prs%CreateStringOption('Hinge_Nodes_Input', &
         'Type of hinge nodes input: parametric or from_file.')
  call hinge_prs%CreateIntOption('N_Nodes','N.hinge nodes')
  call hinge_prs%CreateRealArrayOption('Node1', &
      'First node of the hinge. Components in the local ref.frame of the component')
  call hinge_prs%CreateRealArrayOption('Node2', &
      'Second node of the hinge. Components in the local ref.frame of the component')
  call hinge_prs%CreateRealArrayOption('Hinge_Ref_Dir', &
      'Reference direction of the hinges, indicating zero-deflection direction in &
      &the local ref.frame of the component')
  call hinge_prs%CreateRealOption('Hinge_Offset','Offset in the Ref_Dir needed for &
      &avoiding irregular behavior of the surface for large deflections')
  call hinge_prs%CreateStringOption('Hinge_Rotation_Input', &
      'Input type of the rotation: constant, function, from_file, coupling')
  call hinge_prs%CreateRealOption('Hinge_Rotation_Amplitude', &
      'Amplitude of the rotation, for constant Rotation_Input')
  ! *** to do ***
  ! add all the fields required for all the input types


end subroutine hinge_input_parser

! ---------------------------------------------------------------

end module mod_hinges
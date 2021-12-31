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
!!          Federico Fonte
!!          Davide Montagnani
!!          Matteo Tugnoli
!!=========================================================================


!> Module to treat the most simple input-output from ascii formatted data
!! files
module mod_parametric_io

use mod_param, only: &
  wp, max_char_len, nl, pi

use mod_handling, only: &
  error, warning, info, printout, new_file_unit, check_file_exists

use mod_parse, only: &
  t_parse, getstr, getint, getreal, getrealarray, getlogical, countoption

!----------------------------------------------------------------------

implicit none

public :: read_mesh_parametric, read_actuatordisk_parametric , &
          define_section , define_division

private

character(len=*), parameter :: this_mod_name = 'mod_parametric_io'

!----------------------------------------------------------------------

contains

!----------------------------------------------------------------------

subroutine read_mesh_parametric(mesh_file,ee,rr, &
                     npoints_chord_tot,nelem_span_tot)

 character(len=*), intent(in) :: mesh_file
 integer  , allocatable, intent(out) :: ee(:,:)
 real(wp) , allocatable, intent(out) :: rr(:,:)
 integer  , intent(out), optional    :: npoints_chord_tot, nelem_span_tot

 type(t_parse) :: pmesh_prs
 integer :: ee_size , rr_size

 logical :: twist_linear_interp
 integer :: nelem_chord, nelem_chord_tot ! , nelem_span_tot <--- moved as an output
 integer :: npoint_chord_tot, npoint_span_tot
 integer :: nRegions, nSections
 integer :: iRegion, iSection, iChord, iSpan, iElement, iPoint
 real(wp):: ref_chord_fraction
 real(wp), allocatable :: ref_point(:)
 ! data read from file
 ! sections ---
 real(wp)         , allocatable :: chord_list(:) , twist_list(:)
 character(len=48), allocatable :: airfoil_list(:)
 ! regions  ---
 integer , allocatable :: nelem_span_list(:)
 real(wp), allocatable :: span_list(:) , sweep_list(:) , dihed_list(:)
 character(len=max_char_len), allocatable :: type_span_list(:)
 integer :: n_type_span
 ! Sections 1. 2.
 real(wp), allocatable :: xySection1(:,:) , xySection2(:,:) , xyAirfoil2(:,:)
 real(wp), allocatable :: rrSection1(:,:) , rrSection2(:,:) , xyAirfoil1(:,:)
 real(wp) :: dx_ref , dy_ref , dz_ref
 integer :: ista , iend

 ! Linear interpolation of the twist angle
 real(wp), allocatable :: rr_tw(:,:) , rr_tw_1(:,:) , rr_tw_2(:,:)
 real(wp) :: dx_ref_1, dy_ref_1, dz_ref_1
 real(wp) :: interp_weight

 character :: ElType
 real(wp), allocatable :: chord_fraction(:), span_fraction(:)
 character(len=max_char_len) :: type_chord
 integer :: i1

 integer :: iSec
 real(wp) :: dy_actual_airfoils , dy_sections , csi , twist_rad

 character(len=*), parameter :: this_sub_name = 'read_mesh_parametric'


  !Prepare all the parameters to be read in the file
  ! Global parameters
  call pmesh_prs%CreateStringOption('ElType', &
                'element type (temporary) p panel v vortex ring')
  call pmesh_prs%CreateIntOption('nelem_chord',&
                'number of chord-wise elements', &
                multiple=.false.);
  call pmesh_prs%CreateStringOption('type_chord',&
                'type of chord-wise division: uniform, cosine, cosineLE, cosineTE',&
                'uniform', &
                multiple=.false.);
  call pmesh_prs%CreateRealArrayOption('starting_point',&
               'Starting point (inboard TE), (x, y, z)', &
               '(/0.0, 0.0, 0.0/)',&
               multiple=.false.);
  call pmesh_prs%CreateRealOption('reference_chord_fraction',&
               'Reference chord fraction', &
               '0.0',&
               multiple=.false.);
  call pmesh_prs%CreateLogicalOption('twist_linear_interpolation',&
               'Linear interpolation of the twist angle, for the whole component',&
               'F',&
               multiple=.false.);
  ! TODO: do we really need to allow the user to define the parameter above?
  ! the reference chord fraction is a number in the range [0,1] that defines
  ! - where the reference point is located in the root chord
  ! - the line related to the sweep angle
  ! - the point around which the sections are rotated to impose twist


  ! Section parameters
! already there (few lines above) as a characteristic of the whole component !!!
! call pmesh_prs%CreateRealOption('ref_point_chord', 'reference point of the section (as a fraction of the chord)',&
!               multiple=.true.);
  call pmesh_prs%CreateRealOption(     'chord', 'section chord', &
                multiple=.true.);
  call pmesh_prs%CreateRealOption(     'twist', 'section twist angle', &
                multiple=.true.);
  call pmesh_prs%CreateStringOption( 'airfoil', 'section airfoil', &
                multiple=.true.);

  ! Region parameters
  call pmesh_prs%CreateRealOption(    'span', 'region span',&
                multiple=.true.);
  call pmesh_prs%CreateRealOption(   'sweep', 'region sweep angle [degrees]',&
                multiple=.true.);
  call pmesh_prs%CreateRealOption(   'dihed', 'region dihedral angle [degrees]',&
                multiple=.true.);
  call pmesh_prs%CreateIntOption( 'nelem_span', 'number of span-wise elements in the region',&
                multiple=.true.);
  call pmesh_prs%CreateStringOption('type_span', 'type of span-wise division: &
                &uniform, cosine, cosineIB, cosineOB', multiple=.true.);


  !read the parameters
  call pmesh_prs%read_options(mesh_file,printout_val=.true.)

  nelem_chord = getint(pmesh_prs,'nelem_chord')
  ElType  = getstr(pmesh_prs,'ElType')

  nSections = countoption(pmesh_prs,'chord')
  nRegions  = countoption(pmesh_prs,'span')

  ! Check that nSections = nRegion + 1
  if ( nSections .ne. nRegions + 1 ) then
    call error(this_sub_name, this_mod_name, 'Unconsistent input: &
         &nSections .ne. nRegions. Stop.')
  end if

  ref_chord_fraction = getreal(pmesh_prs,'reference_chord_fraction')
  ref_point          = getrealarray(pmesh_prs,'starting_point',3)

  twist_linear_interp= getlogical(pmesh_prs,'twist_linear_interpolation')

! ! debug ---
!   write(*,*) ' *** twist_linear_interp : ' , twist_linear_interp , ' *** '
! ! debug ---

  !Check the number of inputs
  if(countoption(pmesh_prs,'nelem_span') .ne. nRegions ) &
    call error(this_sub_name, this_mod_name, 'Inconsistent input: &
         &number of "nelem_span" different from number of regions.')
  if(countoption(pmesh_prs,'dihed') .ne. nRegions ) &
    call error(this_sub_name, this_mod_name, 'Inconsistent input: &
         &number of "dihed" different from number of regions.')
  if(countoption(pmesh_prs,'sweep') .ne. nRegions ) &
    call error(this_sub_name, this_mod_name, 'Inconsistent input: &
         &number of "sweep" different from number of regions.')
  if(countoption(pmesh_prs,'twist') .ne. nSections ) &
    call error(this_sub_name, this_mod_name, 'Inconsistent input: &
         &number of "twist" different from number of sections.')
  if(countoption(pmesh_prs,'airfoil') .ne. nSections ) &
    call error(this_sub_name, this_mod_name, 'Inconsistent input: &
         &number of "airfoil" different from number of sections.')

  ! Get total number of elements and initialize arrays
  allocate(nelem_span_list(nRegions));   nelem_span_list = 0
  allocate(      span_list(nRegions));         span_list = 0.0_wp
  allocate(     sweep_list(nRegions));        sweep_list = 0.0_wp
  allocate(     dihed_list(nRegions));        dihed_list = 0.0_wp
  nelem_span_tot = 0
  do iRegion = 1,nRegions
    nelem_span_list(iRegion) = getint(pmesh_prs,'nelem_span')
    span_list(iRegion)  = getreal(pmesh_prs,'span' )
    sweep_list(iRegion) = getreal(pmesh_prs,'sweep')
    dihed_list(iRegion) = getreal(pmesh_prs,'dihed')
    nelem_span_tot = nelem_span_tot + nelem_span_list(iRegion)
  enddo

  ! type_span
  allocate( type_span_list(nRegions));!   type_span_list = ''
  n_type_span = countoption(pmesh_prs,'type_span')
  if ( n_type_span .eq. 0 ) then ! default is 'uniform'
    do iRegion = 1 , nRegions
      type_span_list(iRegion) = 'uniform'
    end do
  else if ( n_type_span .eq. nRegions ) then
    do iRegion = 1 , nRegions
      type_span_list(iRegion) = getstr(pmesh_prs,'type_span')
    end do
  else
   write(*,*) ' mesh_file   : ' , trim(mesh_file)
   write(*,*) ' n_type_span : ' , n_type_span
   write(*,*) ' nRegions    : ' , nRegions
   call error(this_sub_name, this_mod_name, 'Unconsistent input: &
         &n_type_span .ne. nRegions. Stop.')
  end if

  allocate(chord_list  (nSections))  ; chord_list = 0.0_wp
  allocate(twist_list  (nSections))  ; twist_list = 0.0_wp
  allocate(airfoil_list(nSections))
  do iSection= 1,nSections
    chord_list(iSection)   = getreal(pmesh_prs,'chord')
    twist_list(iSection)   = getreal(pmesh_prs,'twist')
    airfoil_list(iSection) = getstr(pmesh_prs,'airfoil')
  enddo

  if (ElType.eq.'p') then
    nelem_chord_tot = 2 * nelem_chord
  else
    nelem_chord_tot = nelem_chord
  endif

  npoint_chord_tot = nelem_chord_tot + 1
  npoint_span_tot  = nelem_span_tot  + 1

  ee_size = nelem_chord_tot * nelem_span_tot
  rr_size = npoint_chord_tot * npoint_span_tot

  ! Directly build connectivity matrix
  allocate(ee(4,ee_size)) ; ee = 0
  do iChord = 1,nelem_chord_tot
    do iSpan = 1,nelem_span_tot
      iElement =  nelem_chord_tot*(iSpan-1) + iChord
      iPoint   = npoint_chord_tot*(iSpan-1) + iChord
      ee(1,iElement) = iPoint + npoint_chord_tot         ! iPoint
      ee(2,iElement) = iPoint                            ! iPoint + 1
      ee(3,iElement) = iPoint + 1                        ! iPoint + npoint_chord_tot + 1
      ee(4,iElement) = iPoint + npoint_chord_tot + 1     ! iPoint + npoint_chord_tot
    enddo
  enddo

  allocate(rr(3,rr_size)) ; rr = 0.0_wp

  ! get chordwise division
  allocate(chord_fraction(nelem_chord+1))
  type_chord = getstr(pmesh_prs,'type_chord')
  call define_division(type_chord, nelem_chord, chord_fraction)


  ! Initialize the span division to the maximum dimension
  allocate(span_fraction(maxval(nelem_span_list))) ; span_fraction = 0.0_wp
  allocate(rrSection1(3,npoint_chord_tot)) ; rrSection1 = 0.0_wp
  allocate(rrSection2(3,npoint_chord_tot)) ; rrSection2 = 0.0_wp

  ! Initialise dr_ref for the definition of the actual reference_point
  !  of each bay (by updating)
  dx_ref = ref_point(1)       ! 0.0_wp
  dy_ref = ref_point(2)       ! 0.0_wp
  dz_ref = ref_point(3)       ! 0.0_wp

  ! === new-2019-02-06 ===
  ! check airfoil_list input ----
  if ( trim(airfoil_list(1)) .eq. 'interp' ) then
    call error(this_sub_name, this_mod_name, 'The first "airfoil"&
          & cannot be set as "interp".')
  end if
  if ( trim(airfoil_list(nSections)) .eq. 'interp' ) then
    call error(this_sub_name, this_mod_name, 'The last "airfoil"&
          & cannot be set as "interp".')
  end if
  ! === new-2019-02-06 ===

  ista = 1 ; iend = npoint_chord_tot
  ! Loop over regions
  do iRegion = 1,nRegions

! check ----
    write(*,*) ' Region ' , iRegion , ' / ' , nRegions
! check ----

    if ( iRegion .gt. 1 ) then  ! first section = last section of the previous region
      rrSection1 = rrSection2
    else                        ! build points
      write(*,*) ' nelem_chord_tot ' , nelem_chord_tot

      call define_section( chord_list(iRegion), trim(adjustl(airfoil_list(iRegion))), &
                           twist_list(iRegion), ElType, nelem_chord,              &
                           type_chord , chord_fraction, ref_chord_fraction,       &
                           ref_point, xySection1 )

      write(*,*) size(rrSection1,1) , size(rrSection1,2)
      write(*,*) size(xySection1,1) , size(xySection1,2)
      rrSection1(1,:) = xySection1(1,:) + ref_point(1)
      rrSection1(2,:) = 0.0_wp          + ref_point(2)     ! <--- read from region structure
      rrSection1(3,:) = xySection1(2,:) + ref_point(3)

      ! Update rr
      rr(:,ista:iend) = rrSection1

    end if


    ! === new-2019-02-06 ===
    ! now, it is possible to define the airfoils on some of the sections only.
    !  When the shape of the airfoil is not defined on a section, it is interpolated
    if ( trim(adjustl(airfoil_list(iRegion+1))) .ne. 'interp' ) then  ! read the field 'airfoil'

      call define_section( chord_list(iRegion+1), trim(adjustl(airfoil_list(iRegion+1))), &
                           twist_list(iRegion+1), ElType, nelem_chord,                    &
                           type_chord , chord_fraction, ref_chord_fraction,               &
                           ref_point, xySection2 )

    else ! interpolation

      do iSec = iRegion + 1 , nRegions+1
        if ( airfoil_list(iSec) .ne. 'interp' ) then
          dy_actual_airfoils = sum( abs(span_list(iRegion:iSec-1)) )
        exit
        end if
      end do
      dy_sections = abs(span_list(iRegion))
      csi = dy_sections / dy_actual_airfoils ! adimensional "coord" for interpolation

      call define_section( 1.0_wp , trim(adjustl(airfoil_list(iSec))), &
                           0.0_wp , ElType, nelem_chord,               &
                           type_chord , chord_fraction, 0.0_wp,        &
                           ref_point, xyAirfoil2 )

      ! Compute the coordinates xySection2(), after removing the offset
      if ( .not. allocated(xySection2) ) &
                  allocate(xySection2(size(xyAirfoil2,1),size(xyAirfoil2,2)))


      if ( allocated(xyAirfoil1) ) deallocate(xyAirfoil1)
      allocate(xyAirfoil1(size(xyAirfoil2,1),size(xyAirfoil2,2)))

      xyAirfoil1(1,:) = ( rrSection1(1,:) - dx_ref ) / chord_list(iRegion)
      xyAirfoil1(2,:) = ( rrSection1(3,:) - dz_ref ) / chord_list(iRegion)

      xyAirfoil1(1,:) =   rrSection1(1,:) + ref_chord_fraction

      twist_rad = twist_list(iRegion) * 4.0_wp * atan(1.0_wp) / 180.0_wp
      xyAirfoil1 = matmul( &
           reshape( (/ cos(twist_rad), sin(twist_rad) , &
                      -sin(twist_rad), cos(twist_rad) /) , (/2,2/) ) , &
                                                          xyAirfoil1 )

!     xySection2(1,:) = ( (1-csi) * xyAirfoil1(1,:) + &
!                            csi  * xyAirfoil2(1,:) ) * chord_list(iRegion+1)
!     xySection2(2,:) = ( (1-csi) * xyAirfoil1(2,:) + &
!                            csi  * xyAirfoil2(2,:) ) * chord_list(iRegion+1)
      xySection2 = ( (1-csi) * xyAirfoil1 + &
                        csi  * xyAirfoil2 ) * chord_list(iRegion+1)
      xySection2(1,:) = xySection2(1,:) - ref_chord_fraction

      twist_rad = twist_list(iRegion+1) * 4.0_wp * atan(1.0_wp) / 180.0_wp
      xySection2 = matmul( &
           reshape( (/ cos(twist_rad),-sin(twist_rad) , &
                       sin(twist_rad), cos(twist_rad) /) , (/2,2/) ) , &
                                                          xySection2 )

    end if
    ! === new-2019-02-06 ===


    if ( abs( sweep_list(iRegion) ) .gt. 60.0_wp ) then
      write(*,*) ' WARNING. abs( sweep_list(iRegion) ) .gt. 60.0_wp. '
    end if
    if ( abs( dihed_list(iRegion) ) .gt. 60.0_wp ) then
      write(*,*) ' WARNING. abs( sweep_list(iRegion) ) .gt. 60.0_wp. '
    end if

    !> save before update
    dx_ref_1 = dx_ref ;  dy_ref_1 = dy_ref ;  dz_ref_1 = dz_ref

    dx_ref = span_list(iRegion) * tan( sweep_list(iRegion)* pi / 180.0_wp ) + dx_ref
    dy_ref = span_list(iRegion)                                             + dy_ref
    dz_ref = span_list(iRegion) * tan( dihed_list(iRegion)* pi / 180.0_wp ) + dz_ref

    rrSection2(1,:) = xySection2(1,:) + dx_ref
    rrSection2(2,:) = 0.0_wp          + dy_ref  ! <--- read from region structure
    rrSection2(3,:) = xySection2(2,:) + dz_ref

    ! Interpolation of the nodes of the region i (between sections i and i+1)
    do i1 = 1 , nelem_span_list(iRegion)

      ista = iend + 1
      iend = iend + npoint_chord_tot

      if ( .not. twist_linear_interp ) then

        ! write(*,*) ; write(*,* )' *** twist_linear_interp = F *** ' ; write(*,*)

        if ( trim(type_span_list(iRegion)) .eq. 'uniform' ) then
          ! uniform spacing in span
          rr(:,ista:iend) = rrSection1 + real(i1,wp) / &
                            real(nelem_span_list(iRegion),wp) * &
                            ( rrSection2 - rrSection1 )
        else if ( trim(type_span_list(iRegion)) .eq. 'cosine' ) then
          ! cosine  spacing in span
          rr(:,ista:iend) = 0.5_wp * ( rrSection1 + rrSection2 ) - &
                            0.5_wp * ( rrSection2 - rrSection1 ) * &
                      cos( real(i1,wp)*pi/ real(nelem_span_list(iRegion),wp) )
        else if ( trim(type_span_list(iRegion)) .eq. 'cosineOB' ) then
          ! cosine  spacing in span: outboard refinement
          rr(:,ista:iend) = rrSection1 + &
                          ( rrSection2 - rrSection1 ) * &
              sin( 0.5_wp*real(i1,wp)*pi/ real(nelem_span_list(iRegion),wp) )
        else if ( trim(type_span_list(iRegion)) .eq. 'cosineIB' ) then
          ! cosine  spacing in span: inboard refinement
          rr(:,ista:iend) = rrSection2 - &
                          ( rrSection2 - rrSection1 ) * &
              cos( 0.5_wp*real(i1,wp)*pi/ real(nelem_span_list(iRegion),wp) )
        else
          write(*,*) ' mesh_file   : ' , trim(mesh_file)
          write(*,*) ' type_span_list(',iRegion,') : ' , trim(type_span_list(iRegion))
          call error(this_sub_name, this_mod_name, 'Unconsistent input: &
                & type_span must be equal to uniform, cosine, cosineIB, cosineOB.')
        end if

      else !-> linear interpolation of the twist angle

        ! write(*,*) ; write(*,* )' *** twist_linear_interp = T *** ' ; write(*,*)

        allocate(rr_tw(  2,npoint_chord_tot))
        allocate(rr_tw_1(2,npoint_chord_tot))
        allocate(rr_tw_2(2,npoint_chord_tot))

        ! === Transform sections back to local reference frames ===
        ! Section 1
        !> remove offset in x,z
        rr_tw_1(1,:) = rrSection1(1,:) - dx_ref_1
        rr_tw_1(2,:) = rrSection1(3,:) - dz_ref_1
        !> rotate section back ( coord. in the local ref. frame )
        twist_rad = twist_list(iRegion) * pi/180.0_wp
        rr_tw_1 = matmul( &
             reshape( (/ cos(twist_rad), sin(twist_rad) , &
                        -sin(twist_rad), cos(twist_rad) /) , (/2,2/) ) , &
                                                               rr_tw_1 )
        ! Section 2
        !> remove offset in x,z
        rr_tw_2(1,:) = rrSection2(1,:) - dx_ref
        rr_tw_2(2,:) = rrSection2(3,:) - dz_ref
        !> rotate section back ( coord. in the local ref. frame )
        twist_rad = twist_list(iRegion+1) * pi/180.0_wp
        rr_tw_2 = matmul( &
             reshape( (/ cos(twist_rad), sin(twist_rad) , &
                        -sin(twist_rad), cos(twist_rad) /) , (/2,2/) ) , &
                                                               rr_tw_2 )
        ! === Interpolation weight ===
        if ( trim(type_span_list(iRegion)) .eq. 'uniform' ) then
          interp_weight = real(i1,wp) / real(nelem_span_list(iRegion),wp)
        else if ( trim(type_span_list(iRegion)) .eq. 'cosine' ) then
          interp_weight = 0.5_wp * ( &
                        1.0_wp - cos( real(i1,wp)*pi/ real(nelem_span_list(iRegion),wp) ) )
        else if ( trim(type_span_list(iRegion)) .eq. 'cosineOB' ) then
          interp_weight = sin( 0.5_wp*real(i1,wp)*pi/ real(nelem_span_list(iRegion),wp) )
        else if ( trim(type_span_list(iRegion)) .eq. 'cosineIB' ) then
          interp_weight = 1.0_wp - cos( 0.5_wp*real(i1,wp)*pi/ real(nelem_span_list(iRegion),wp) )
          ! interp_weight = cos( 0.5_wp*real(i1,wp)*pi/ real(nelem_span_list(iRegion),wp) )
        else
          write(*,*) ' mesh_file   : ' , trim(mesh_file)
          write(*,*) ' type_span_list(',iRegion,') : ' , trim(type_span_list(iRegion))
          call error(this_sub_name, this_mod_name, 'Unconsistent input: &
                & type_span must be equal to uniform, cosine, cosineIB, cosineOB.')
        end if

        ! === x,z coordinates ===
        rr_tw = rr_tw_1 + ( rr_tw_2 - rr_tw_1 ) * interp_weight
        !> rotation ( linear interpolation of the twist angle )
        twist_rad = pi/180.0_wp * ( twist_list(iRegion) + &
            ( twist_list(iRegion+1)-twist_list(iRegion) ) * interp_weight )
        rr_tw = matmul( &
             reshape( (/ cos(twist_rad),-sin(twist_rad) , &
                         sin(twist_rad), cos(twist_rad) /) , (/2,2/) ) , &
                                                                 rr_tw )
        rr(1,ista:iend) = rr_tw(1,:) + dx_ref_1 + &
                            ( dx_ref - dx_ref_1 ) * interp_weight
        rr(3,ista:iend) = rr_tw(2,:) + dz_ref_1 + &
                            ( dz_ref - dz_ref_1 ) * interp_weight
        ! === y coordinate ===
        rr(2,ista:iend) = rrSection1(2,:) + &
                        ( rrSection2(2,:) - rrSection1(2,:) ) * interp_weight

        deallocate(rr_tw, rr_tw_1, rr_tw_2)


      end if

    end do


  enddo

  ! lots of deallocation missing causing memory leakage =(
  if ( allocated(xySection1) ) deallocate(xySection1)
  if ( allocated(xySection2) ) deallocate(xySection2)
  ! ...

  ! optional output ----
  npoints_chord_tot = npoint_chord_tot
  ! optional output ----


end subroutine read_mesh_parametric

!-------------------------------------------------------------------------------

subroutine define_section(chord, airfoil, twist, ElType, nelem_chord, &
                           type_chord , chord_fraction, reference_chord_fraction,&
                           reference_point, point_list)

  real(wp), allocatable , intent(out) :: point_list(:,:)
  real(wp), intent(in) :: reference_point(:), chord_fraction(:)
  character(len=*) , intent(in) :: type_chord
  real(wp), intent(in) :: reference_chord_fraction, twist, chord
  integer, intent(in) :: nelem_chord
  character, intent(in) :: ElType
  character(len=*) , intent(in) :: airfoil

  real(wp), allocatable :: points_mean_line(:,:)
  real(wp) :: twist_rad

  character(len=*), parameter :: this_sub_name='define_section'

!  character(len=4) :: char_ini4 , char_fin4

  integer :: i1

! write(*,*) ' airfoil input ' , airfoil

  twist_rad = twist * 4.0_wp * atan(1.0_wp) / 180.0_wp

  ! Airfoil geometry +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  ! - read coordinate from file: if <airfoil> is 'xxxxxx.dat'
  ! - build as a member of a airfoil family:
  !   - NACA 4-digit: NACAmpss
  !   - NACA 5-digit: NACAxxxxx
  !   - ...
  if ( airfoil(len_trim(airfoil)-3 : len_trim(airfoil)) .eq. '.dat' ) then

    call check_file_exists(airfoil, this_sub_name, this_mod_name)
    call read_airfoil ( airfoil , trim(type_chord) , ElType , nelem_chord , point_list )
    do i1 = 1 , size(point_list,2)
      write(*,*) point_list(:,i1)
    end do

  else if ( airfoil(1:4) .eq. 'NACA' ) then
    if ( len_trim(airfoil) .eq. 8 ) then      ! NACA 4-digit -------
      call naca4digits(airfoil(5:8), nelem_chord, chord_fraction, &
                        points_mean_line , point_list )

      if ( ElType .eq. 'v' ) then
        deallocate(point_list)
        allocate( point_list(size(points_mean_line,1),size(points_mean_line,2)) )
        point_list = points_mean_line
      end if

    elseif ( len_trim(airfoil) .eq. 9 ) then
      call naca5digits(airfoil(5:9), nelem_chord, chord_fraction, &
                        points_mean_line , point_list )

      if ( ElType .eq. 'v' ) then
        deallocate(point_list)
        allocate( point_list(size(points_mean_line,1),size(points_mean_line,2)) )
        point_list = points_mean_line
      end if
    end if

  else
    call error(this_sub_name, this_mod_name, ' only 4-digit and some 5-digit &
      &NACA airfoils implemented. Provide the coordinates of the airfoil as&
      & a .dat file ')
  end if


  ! Geometric transformation +++++++++++++++++++++++++++++++++++++++++++++++++++
  ! 1. translation : reference_chord_fraction (defined for a unit-chord airfoil)
  point_list(1,:) = point_list(1,:) - reference_chord_fraction
  ! 2. scaling     : chord
  point_list = point_list * chord
  ! 3. rotation    : twist
  point_list = matmul( reshape( (/ cos(twist_rad),-sin(twist_rad) , &
                                   sin(twist_rad), cos(twist_rad) /) , (/2,2/) ) , &
                                                                     point_list )


end subroutine define_section

!-------------------------------------------------------------------------------

subroutine naca4digits(airfoil_name, nelem_chord,&
                       chord_fraction, & ! points_upper, points_lower)
                       points_mean_line , points )
  character(len=*), intent(in) :: airfoil_name
  integer , intent(in)  :: nelem_chord
  real(wp), intent(in)  :: chord_fraction(:)
  real(wp), allocatable , intent(out) :: points_mean_line(:,:), points(:,:)

  real(wp), allocatable :: points_upper(:,:), points_lower(:,:)

  integer :: mm, pp, ss, iPoint
  real(wp) :: m,p,s, xa, ml, theta, thickness
  character :: str1
  character(len=2) :: str2
  integer :: ierr

  str1 = airfoil_name(1:1)
  read(str1,*,iostat=ierr) mm
  str1 = airfoil_name(2:2)
  read(str1,*,iostat=ierr) pp
  str2 = airfoil_name(3:4)
  read(str2,*,iostat=ierr) ss

  m = real(mm,wp)/100.0_wp
  p = real(pp,wp)/10.0_wp
  s = real(ss,wp)/100.0_wp

  allocate(points_upper(2,nelem_chord+1)) ; points_upper = 0.0_wp
  allocate(points_lower(2,nelem_chord+1)) ; points_lower = 0.0_wp

  if ( allocated(points_mean_line) )  deallocate(points_mean_line)
  allocate(points_mean_line(2,nelem_chord+1)) ; points_mean_line = 0.0_wp

  do iPoint = 1,nelem_chord+1

    xa = chord_fraction(iPoint)

    ! Define mean line ml and local slope theta
    ml = 0.0_wp
    theta = 0.0_wp
    if (p>0) then
      if (xa <= p) then
        ml = m/p**2 * (2.0_wp*p*xa - xa**2)
        theta = 2.0_wp*m/p**2 * (p - xa)
      else
        ml = m/(1.0_wp-p)**2 * (1.0_wp-2.0_wp*p + 2.0_wp*p*xa - xa**2)
        theta = 2.0_wp*m/(1.0_wp-p)**2 * (p - xa)
      endif
    endif

    ! Thickness
    thickness = 5.0_wp*s*( 0.2969_wp*sqrt(xa)  &
                         - 0.1260_wp* xa       &
                         - 0.3516_wp*(xa**2)   &
                         + 0.2843_wp*(xa**3)   &
                         - 0.1036_wp*(xa**4))     ! closed TE
!                        - 0.1015_wp*(xa**4))     !   open TE

    points_mean_line(1,iPoint) = xa
    points_mean_line(2,iPoint) = ml

    points_upper(1,iPoint) = xa - thickness*sin(theta)
    points_upper(2,iPoint) = ml + thickness*cos(theta)

    points_lower(1,iPoint) = xa + thickness*sin(theta)
    points_lower(2,iPoint) = ml - thickness*cos(theta)

  enddo

  if ( allocated(points) ) deallocate(points)
  allocate(points(2,2*nelem_chord+1))
  points(:,            1:  nelem_chord  ) = points_lower(:,nelem_chord+1:2:-1)
  points(:,nelem_chord+1:2*nelem_chord+1) = points_upper


endsubroutine naca4digits

!----------------------------------------------------------------------

subroutine naca5digits(airfoil_name, nelem_chord,&
                       chord_fraction, & ! points_upper, points_lower)
                       points_mean_line , points )
 character(len=*), intent(in) :: airfoil_name
 integer , intent(in)  :: nelem_chord
 real(wp), intent(in)  :: chord_fraction(:)
 real(wp), allocatable , intent(out) :: points_mean_line(:,:), points(:,:)

 real(wp), allocatable :: points_upper(:,:), points_lower(:,:)

 integer :: ss, iPoint, L, Q, P
 real(wp) :: s, xa, ml, theta, thickness, mult, r, k1
 character :: str1
 character(len=2) :: str2
 integer :: ierr
 character(len=*), parameter :: this_sub_name = 'naca5digits'


  str1 = airfoil_name(1:1)
  read(str1,*,iostat=ierr) L
  str1 = airfoil_name(2:2)
  read(str1,*,iostat=ierr) P
  str1 = airfoil_name(3:3)
  read(str1,*,iostat=ierr) Q
  str2 = airfoil_name(4:5)
  read(str2,*,iostat=ierr) ss

  s = real(ss,wp)/100.0_wp

  !A limited number of airfoils have been implemented, perform some checks...
  if(Q .ne. 0) call error(this_sub_name, this_mod_name, &
                          'Reverse 5 digits naca profiles not yet implemented')
  select case(P)
   case(1)
    r = 0.0580_wp
    k1 = 361.400_wp
   case(2)
    r = 0.1260_wp
    k1 = 51.640_wp
   case(3)
    r = 0.2025_wp
    k1 = 15.957_wp
   case(4)
    r = 0.2900_wp
    k1 = 6.643_wp
   case(5)
    r = 0.0580_wp
    k1 = 3.230_wp
   case default
    call error(this_sub_name, this_mod_name, &
                          '5 digit naca not valid')
  end select

  !camber is created for 0.3 of design Cl (L=2). All others are generated by
  !linearly scaling the camber
  mult = (real(L,wp)*3.0_wp/20.0_wp) / 0.3_wp

  allocate(points_upper(2,nelem_chord+1)) ; points_upper = 0.0_wp
  allocate(points_lower(2,nelem_chord+1)) ; points_lower = 0.0_wp

  if ( allocated(points_mean_line) )  deallocate(points_mean_line)
  allocate(points_mean_line(2,nelem_chord+1)) ; points_mean_line = 0.0_wp

  do iPoint = 1,nelem_chord+1

    xa = chord_fraction(iPoint)

    ! Define mean line ml and local slope theta
    ml = 0.0_wp
    theta = 0.0_wp
    if (xa <= r) then
      ml = mult*k1/6.0_wp*(xa**3 -3.0_wp*r*xa**2+r**2*(3.0_wp-r)*xa)
      theta = mult*k1/6.0_wp*(3.0_wp*xa**2 -6.0_wp*r*xa+r**2*(3.0_wp-r))
    else
      ml = mult*k1*r**3/6.0_wp*(1-xa)
      theta = -mult*k1*r**3/6.0_wp
    endif

    ! Thickness
    thickness = 5.0_wp*s*(0.2969_wp*sqrt(xa) - 0.1260_wp*xa - 0.3516_wp*(xa**2) + 0.2843_wp*(xa**3) - 0.1015_wp*(xa**4))

    points_mean_line(1,iPoint) = xa
    points_mean_line(2,iPoint) = ml

    points_upper(1,iPoint) = xa - thickness*sin(theta)
    points_upper(2,iPoint) = ml + thickness*cos(theta)

    points_lower(1,iPoint) = xa + thickness*sin(theta)
    points_lower(2,iPoint) = ml - thickness*cos(theta)

  enddo

  if ( allocated(points) ) deallocate(points)
  allocate(points(2,2*nelem_chord+1))
  points(:,            1:  nelem_chord  ) = points_lower(:,nelem_chord+1:2:-1)
  points(:,nelem_chord+1:2*nelem_chord+1) = points_upper


endsubroutine naca5digits

!-------------------------------------------------------------------------------

subroutine read_airfoil ( filen , discr , ElType , nelems_chord , rr )

 character(len=*), intent(in) :: filen
 character(len=*), intent(in) :: discr
 character(len=*), intent(in) :: ElType
 integer         , intent(in) :: nelems_chord
 real(wp)        , allocatable , intent(out):: rr(:,:)

 integer :: nelems_chord_tot
 real(wp) , allocatable :: rr_geo(:,:)
 integer :: np_geo
 real(wp) , allocatable :: csi_half(:) , csi(:)
 real(wp) , allocatable :: st_geo(:) , s_geo(:)
 real(wp) :: ds_geo

 integer :: fid
 integer :: i1 , i2

 ! Read coordinates
 fid = 21
 write(*,*) ' reading file : **',trim(adjustl(filen)) , '**'
 open(unit=fid,file=trim(adjustl(filen)) )
 read(fid,*) np_geo
 allocate(rr_geo(2,np_geo))
 do i1 = 1 , np_geo
  read(fid,*) rr_geo(:,i1)
 end do
 close(fid)

 allocate(csi_half(nelems_chord+1))
 select case (trim(discr))
 case('uniform')
   do i1 = 1 , nelems_chord+1
     csi_half(i1) = real(i1-1,wp)/real(nelems_chord,wp)
   end do
 case('cosine')
   do i1 = 1 , nelems_chord+1
     csi_half(i1) = (1.0_wp - cos(pi*real(i1-1,wp)/real(nelems_chord,wp)) )&
                                                                    / 2.0_wp
   end do
 case('cosineLE' , 'cosineIB')
   do i1 = 1 , nelems_chord+1
     csi_half(i1) = sin(pi/2.0_wp*real(i1-1,wp)/real(nelems_chord,wp))
   end do
 case('cosineTE' , 'cosineOB')
   do i1 = 1 , nelems_chord+1
     csi_half(i1) = (1.0_wp - cos(pi/2.0_wp*real(i1-1,wp) &
                                  /real(nelems_chord,wp)) )
   end do
 case default
 end select

 if ( ElType .eq. 'p' ) then
   nelems_chord_tot = 2*nelems_chord+1
   allocate(csi(nelems_chord_tot))
   csi(             1  :nelems_chord+1) = 0.5_wp * csi_half
   csi(nelems_chord+2:2*nelems_chord+1) =-0.5_wp * csi_half(nelems_chord:1:-1) + 1.0_wp
 elseif ( ElType .eq. 'v' ) then
   nelems_chord_tot = nelems_chord+1
   allocate(csi(nelems_chord_tot))
   csi = -csi_half(nelems_chord+1:1:-1) + 1.0_wp
 end if

  ! check ----
   write(*,*) ' csi.  size(csi) = ' , size(csi)
   do i1 = 1 , size(csi)
    write(*,*) csi(i1)
   end do
   write(*,*)
  ! check ----

 allocate(st_geo(np_geo),s_geo(np_geo))
 st_geo = 0.0_wp ; s_geo = 0.0_wp
 ! st_geo(1) = s_geo(1) = 0.0_wp

 do i1 = 2 , np_geo
  st_geo(i1) = st_geo(i1-1) + norm2(rr_geo(:,i1)-rr_geo(:,i1-1))
 end do
 s_geo = st_geo / st_geo(np_geo)


 allocate(rr(2,nelems_chord_tot)) ; rr = 0.0_wp
 rr(:,1) = rr_geo(:,1)
 rr(:,nelems_chord_tot) = rr_geo(:,np_geo)
 do i1 = 2 , nelems_chord_tot - 1
   do i2 = 2 , np_geo

     if ( csi(i1) .lt. s_geo(i2) ) then
       ds_geo = s_geo(i2)-s_geo(i2-1)
       rr(:,i1) = (csi(i1)-s_geo(i2-1))/ds_geo * rr_geo(:,i2) + &
                  (s_geo(i2)-csi(i1)  )/ds_geo * rr_geo(:,i2-1)
       exit
     end if

   end do
 end do

 do i1 = 1 , size(rr,2)
  write(*,*) rr(:,i1)
 end do


end subroutine read_airfoil

!-------------------------------------------------------------------------------
subroutine define_division(type_mesh, nelem, division)

  real(wp), intent(out) :: division(:)
  integer, intent(in) :: nelem
  character(len=*), intent(in) :: type_mesh

  real(wp) :: step
  integer :: iPoint

  division = 0.0_wp
  step = 1.0_wp/real(nelem,wp)

  select case (trim(type_mesh))
  case ("uniform")
    do iPoint = 1,nelem+1
      division(iPoint) = (real(iPoint-1,wp))*step
    enddo
  case ("cosine")
    do iPoint = 1,nelem+1
      division(iPoint) = (1.0_wp - cos(pi*(real(iPoint-1,wp))*step))/2.0_wp
    enddo
  case ("cosineLE", "cosineIB")
    do iPoint = 1,nelem+1
      division(iPoint) = 1.0_wp - cos(pi/2.0_wp*(real(iPoint-1,wp))*step)
    enddo
  case ("cosineTE", "cosineOB")
    do iPoint = 1,nelem+1
!     division(iPoint) = - cos(pi/2.0_wp*((iPoint-1)*step+1.0_wp))
      division(iPoint) = sin(pi/2.0_wp*((real(iPoint-1,wp))*step))
    enddo
  case default
    ! TODO: error in this case
  end select

end subroutine define_division

!-------------------------------------------------------------------------------

subroutine read_actuatordisk_parametric(mesh_file,ee,rr)
 character(len=*), intent(in) :: mesh_file
 integer  , allocatable, intent(out) :: ee(:,:)
 real(wp) , allocatable, intent(out) :: rr(:,:)

 real(wp), allocatable :: x(:), y(:)
 type(t_parse) :: pmesh_prs
 character :: ElType
 integer :: nstep, ax, ip
 real(wp) :: r, theta
 integer :: ind1, ind2
 character(len=*), parameter ::  this_sub_name = 'read_actuatordisk_parametric'

  call pmesh_prs%CreateStringOption('ElType', &
                'element type (temporary) p panel v vortex ring &
                & l lifting line a actuator disk')
  call pmesh_prs%CreateRealOption('Radius', 'Radius of the actuator disk')
  call pmesh_prs%CreateIntOption('nstep','Number of subdivisions')
  call pmesh_prs%CreateIntOption('Axis','Which axis to align the disk')

  !read the parameters
  call pmesh_prs%read_options(trim(mesh_file),printout_val=.true.)

  ElType = getstr(pmesh_prs,'ElType')

  if(trim(ElType) .ne. 'a') call error(this_sub_name, this_mod_name, &
    'This should have not happened, a team of professionals is under way to &
    &remove the evidence')

  r = getreal(pmesh_prs,'Radius')
  nstep = getint(pmesh_prs,'nstep')
  ax = getint(pmesh_prs,'Axis')


  allocate(x(nstep), y(nstep))

  do ip = 1, nstep
    theta = real(ip-1,wp) * 2.0_wp*pi/real(nstep,wp)
    x(ip) = cos(theta)*r
    y(ip) = sin(theta)*r
  enddo

  ind1 = 1+mod(ax,3)
  ind2 = 1+mod(ind1,3)
  allocate(rr   (3,nstep)) ; rr = 0.0_wp
  rr(ind1,:) = x
  rr(ind2,:) = y

  allocate(ee(nstep,1)) ; ee = 0
  do ip = 1,nstep
    ee(ip,1) = ip
  enddo

  deallocate(x,y)

end subroutine read_actuatordisk_parametric

!-------------------------------------------------------------------------------

end module mod_parametric_io

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

!> Module containing the subroutines to perform output of specific data
!! required for aeroacoustics computations
module mod_post_aa

use mod_param, only: &
  wp, nl, max_char_len, extended_char_len , pi

use mod_handling, only: &
  error, warning, info, printout, dust_time, t_realtime, new_file_unit

use mod_parse, only: &
  t_parse, &
  getstr, getlogical, &
  countoption

use mod_hdf5_io, only: &
   h5loc, &
   open_hdf5_file, &
   close_hdf5_file, &
   open_hdf5_group, &
   close_hdf5_group, &
   read_hdf5, &
   read_hdf5_attr

use mod_stringtools, only: &
  LowCase, isInList

use mod_geometry, only: &
  t_geo, t_geo_component, destroy_elements

use mod_geo_postpro, only: &
  load_components_postpro, update_points_postpro, prepare_geometry_postpro, &
  expand_actdisk_postpro

use mod_post_load, only: &
  load_refs, load_res, load_wake_viz , check_if_components_exist

use mod_dat_out, only: &
  dat_out_aa_header, dat_out_aa

use mod_surfpan, only: &
  t_surfpan

implicit none

public :: post_aeroacoustics

private

character(len=*), parameter :: this_mod_name='mod_post_aa'
character(len=max_char_len) :: msg

contains

! ---------------------------------------------------------------------- 

subroutine post_aeroacoustics( sbprms, basename, data_basename, an_name, ia, &
                     out_frmt, components_names, all_comp, an_start, an_end, &
                     an_step, average )
 type(t_parse), pointer :: sbprms
 character(len=*) , intent(in) :: basename
 character(len=*) , intent(in) :: data_basename
 character(len=*) , intent(in) :: an_name
 integer          , intent(in) :: ia
 character(len=*) , intent(in) :: out_frmt
 character(len=max_char_len), allocatable , intent(inout) :: components_names(:)
 logical , intent(in) :: all_comp
 integer , intent(in) :: an_start , an_end , an_step
 logical, intent(in) :: average
 
 type(t_geo_component), allocatable :: comps(:)
 character(len=max_char_len) :: filename
 integer(h5loc) :: floc , ploc
 real(wp), allocatable :: points(:,:)
 integer :: nelem
 
 real(wp) :: u_inf(3)
 real(wp) :: P_inf , rho, mu_inf, a_inf, time

 integer :: fid_out

 integer :: i_comp, ie, ierr

 real(wp), allocatable :: refs_R(:,:,:), refs_off(:,:)
 real(wp), allocatable :: refs_G(:,:,:), refs_f(:,:)
 real(wp), allocatable :: vort(:), press(:), surfvel(:,:)
 
 integer :: it, ires
 real(wp) :: t
 character(len=*), parameter :: this_sub_name='post_aeroacoustics'

  write(msg,'(A,I0,A)') nl//'++++++++++ Analysis: ',ia,' aeroacoustics'//nl
  call printout(trim(msg))
  
  ! Load the components (just once)
  call open_hdf5_file(trim(data_basename)//'_geo.h5', floc)
  
  call load_components_postpro(comps, points, nelem, floc, &
                               components_names, all_comp)
  
  call close_hdf5_file(floc)
  
  
  if( average ) call error(this_sub_name, this_mod_name, &
    'Cannot output an averaged aeroacoustics analysis')
  if(trim(out_frmt) .ne. 'dat') call error(this_sub_name, this_mod_name, &
    'aeroacoustics analysis available only in dat ascii file format')

  ! Prepare_geometry_postpro
  call prepare_geometry_postpro(comps)
  
  ! Time loop
  ires = 0
  do it = an_start, an_end, an_step
    ires = ires+1
  
    ! Open the file 
    write(filename,'(A,I4.4,A)') trim(data_basename)//'_res_',it,'.h5'
    call open_hdf5_file(trim(filename),floc)
  
    ! Load free-stream parameters
    call open_hdf5_group(floc,'Parameters',ploc)
    call read_hdf5(u_inf,'u_inf',ploc)
    call read_hdf5(P_inf,'P_inf',ploc)
    call read_hdf5(rho,'rho_inf',ploc)
    !get from the attributes
    call read_hdf5_attr(mu_inf,'mu_inf',floc)
    call read_hdf5_attr(a_inf,'a_inf',floc)
    call read_hdf5(time,'time',floc)
    call close_hdf5_group(ploc)
  
    ! Load the references
    call load_refs(floc, refs_R, refs_off, refs_G, refs_f)
  
    ! Move the points
    call update_points_postpro(comps, points, refs_R, refs_off)
  
    !Load the results
    call load_res(floc, comps, vort, press, t, surfvel)
  
    
    ! Output filename
    write(filename,'(A,I4.4,A)') trim(basename)//'_'//trim(an_name)//'-',it,&
                                 '.dat'
    !open the file
    call new_file_unit(fid_out, ierr)
    open(unit=fid_out,file=trim(filename)) 

    !write the header here
    call dat_out_aa_header( fid_out, time, P_inf, rho, a_inf, mu_inf, u_inf  )

    !cycle on components
    do i_comp = 1,size(comps)
    associate(comp => comps(i_comp))
      !cycle on elements
      do ie = 1,size(comp%el)
      select type(el =>comp%el(ie))
        !print a line of the file for each element
        
       type is(t_surfpan)
        call dat_out_aa( fid_out, el%cen, el%nor, el%area, el%ub, &
                         el%surf_vel, el%dforce )
       class default
        call dat_out_aa( fid_out, el%cen, el%nor, el%area, el%ub, &
                         (/0.0_wp, 0.0_wp, 0.0_wp/), el%dforce )
      end select
      enddo
    end associate
    enddo

    !close the file
    
  
  
    deallocate(refs_R, refs_off, refs_G, refs_f)
  
    if (allocated(vort ) ) deallocate(vort )
    if (allocated(press) ) deallocate(press)
    if (allocated(press) ) deallocate(surfvel)
  
  
  end do ! Time loop

  
  deallocate(points)
  call destroy_elements(comps)
  deallocate(comps)
  
  write(msg,'(A,I0,A)') nl//'++++++++++ Aeroacoustics done'//nl
  call printout(trim(msg))

end subroutine post_aeroacoustics

! ---------------------------------------------------------------------- 

end module mod_post_aa

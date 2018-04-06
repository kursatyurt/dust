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


!> Module to treat the most simple input-output from ascii formatted data
!! files
module mod_basic_io

use mod_param, only: &
  wp, max_char_len, nl

use mod_handling, only: &
  error, warning, info, printout, new_file_unit

!----------------------------------------------------------------------

implicit none

public :: read_mesh_basic, write_basic

private

interface write_basic
  module procedure write_basic_real
  module procedure write_basic_int
end interface

character(len=*), parameter :: this_mod_name = 'mod_basic_io'

!----------------------------------------------------------------------

contains

!----------------------------------------------------------------------

subroutine read_mesh_basic(mesh_file,ee,rr)
 
 character(len=*), intent(in) :: mesh_file
 integer  , allocatable, intent(out) :: ee(:,:) 
 real(wp) , allocatable, intent(out) :: rr(:,:) 
 
 character(len=max_char_len) :: filen_ee , filen_rr
 integer :: ee_size , rr_size
 integer :: io_error
 integer :: fid, fid_err
 integer :: i1
 logical :: file_exists
 character(len=*), parameter :: this_sub_name = 'read_mesh_basic'

  filen_ee = trim(mesh_file//'ee.dat')
  filen_rr = trim(mesh_file//'rr.dat')

  ! ee
  inquire(file=trim(adjustl(filen_ee)), exist=file_exists)
  if (.not. file_exists) then
   call error(this_sub_name, this_mod_name, &
        'File '//trim(filen_ee)//' does not exist')
  endif
  
  ! read # of lines
  call new_file_unit(fid, fid_err)
  open(unit=fid, file=trim(adjustl(filen_ee)), action='read', iostat=io_error )
  do i1 = 1 , 1000000
  ! write(*,*) i1
    read(fid,*,iostat=io_error) ! dummy
    if ( io_error  .lt. 0 ) then
      ee_size = i1-1
      exit
    end if
  end do
  close(fid)
  
  ! read file
  call new_file_unit(fid, fid_err)
  allocate(ee(4,ee_size)) ; ee = 0
  open(unit=fid, file=trim(adjustl(filen_ee)), action='read', iostat=io_error )
  do i1 = 1 , ee_size
    read(fid,*) ee(:,i1)
  end do
  close(fid)
  
  ! rr
  inquire(file=trim(adjustl(filen_rr)), exist=file_exists)
  if (.not. file_exists) then
   call error(this_sub_name, this_mod_name, &
        'File '//trim(filen_rr)//' does not exist')
  endif
  ! read # of lines
  call new_file_unit(fid, fid_err)
  open(unit=fid, file=trim(adjustl(filen_rr)), action='read', iostat=io_error )
  do i1 = 1 , 1000000
  ! write(*,*) i1
    read(fid,*,iostat=io_error) ! dummy
    if ( io_error  .lt. 0 ) then
      rr_size = i1-1
      exit
    end if
  end do
  close(fid)
  
  ! read file
  call new_file_unit(fid, fid_err)
  allocate(rr(3,rr_size)) ; rr = 0.0_wp
  open(unit=fid, file=trim(adjustl(filen_rr)), action='read', iostat=io_error )
  do i1 = 1 , rr_size
    read(fid,*) rr(:,i1)
  end do
  close(fid)
  
  
end subroutine read_mesh_basic

!----------------------------------------------------------------------

subroutine write_basic_real(aa, filename)
 real(wp), intent(in) :: aa(:,:)
 character(len=*), intent(in) :: filename

 integer :: fid, fid_err, i

 call new_file_unit(fid, fid_err)

 open(unit=fid, file=trim(adjustl(filename)) )
 do i = 1 , size(aa,2)
  write(fid,*) aa(:,i)
 end do
 close(fid)

end subroutine write_basic_real

!----------------------------------------------------------------------

subroutine write_basic_int(aa, filename)
 integer, intent(in) :: aa(:,:)
 character(len=*), intent(in) :: filename

 integer :: fid, fid_err, i

 call new_file_unit(fid, fid_err)

 open(unit=fid, file=trim(adjustl(filename)) )
 do i = 1 , size(aa,2)
  write(fid,*) aa(:,i)
 end do
 close(fid)

end subroutine write_basic_int
!----------------------------------------------------------------------

end module mod_basic_io

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


!> Module containing parameters for the code execution

module mod_param

!----------------------------------------------------------------------

implicit none

!----------------------------------------------------------------------

public :: wp, & 
          max_char_len , &
          extended_char_len, &
          nl, &
          pi , &
          eps, &
          prev_tri , next_tri , &
          prev_qua , next_qua, &
          ascii_real

private

!----------------------------------------------------------------------

!----------------------------------------------------------------------
! Select here the working precision wp
!
! single precision
!integer, parameter :: wp = selected_real_kind(6,35)
!
! double precision
integer, parameter :: wp = selected_real_kind(12,307)
!
! quadruple precision
!integer, parameter :: wp = selected_real_kind(30,307)
!----------------------------------------------------------------------

integer, parameter :: max_char_len = 255

integer, parameter :: extended_char_len = 1000

character, parameter :: nl = new_line('a')

character(len=*), parameter :: &
   ascii_real = 'e24.15e3' ! format: _+0.***************E+***

!----------------------------------------------------------------------
! mathematical parameters and usefull constants & arrays

real(wp), parameter :: pi = 4.0_wp * atan(1.0_wp)

integer, parameter :: prev_tri(3) = (/ 3 , 1 , 2 /)
integer, parameter :: next_tri(3) = (/ 2 , 3 , 1 /)
integer, parameter :: prev_qua(4) = (/ 4 , 1 , 2 , 3 /)
integer, parameter :: next_qua(4) = (/ 2 , 3 , 4 , 1 /)


real(wp), parameter :: eps = 1.0e-10_wp

!----------------------------------------------------------------------

!type :: t_param_dict
!
! character(len=1) :: actdisk = 'a'
!
! character(len=1) :: liftlin = 'l'
!
! character(len=1) :: surfpan = 'p'
!
! character(len=1) :: vortpan = 'v'
!
!
!end type t_param_dict
!
!type(t_param_dict) :: dict

!----------------------------------------------------------------------

end module mod_param

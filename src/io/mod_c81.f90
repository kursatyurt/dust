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


! SUBROUTINEs:
!   read_c81_table
!   interp2d

!> Module to treat the c81 tables
module mod_c81

use mod_param, only: &
  wp, max_char_len , nl

use mod_handling, only: &
  error, warning

implicit none

!-----------------------------------

! public and private

!-----------------------------------

type t_aero_2d_par
  real(wp) , allocatable :: par1(:)
  real(wp) , allocatable :: par2(:)
  real(wp) , allocatable :: cf(:,:)
end type t_aero_2d_par

!-----------------------------------

type t_aero_2d_tab

 !> value of the third parameter, Re
 real(wp) :: Re

 type(t_aero_2d_par) , allocatable :: coeff(:)
 real(wp) , allocatable :: dclda(:,:)

 real(wp) , allocatable :: clmax(:) , alcl0(:) , cdmin (:)
 real(wp) , allocatable :: clstall_neg(:) , clstall_pos(:) 
 real(wp) , allocatable :: alstall_neg(:) , alstall_pos(:) 

!!> cl(a,M,Re) 3d-data (extrapolation on Re or no dependence from Re)
!real(wp) , allocatable :: cl(:,:)
!type(t_aero_par) :: cl_par
!
!!> cd(a,M,Re) 3d-data
!real(wp) , allocatable :: cd(:,:)
!type(t_aero_par) :: cd_par
!
!!> cm(a,M,Re) 3d-data
!real(wp) , allocatable :: cm(:,:)
!type(t_aero_par) :: cm_par

end type t_aero_2d_tab

!-----------------------------------

!> Tables containing aerodynamic coefficients
!!
!! Tabulated data for lifting line elements 
type t_aero_tab

 !> airfoil file
 character(len=max_char_len) :: airfoil_file 

 !> airfoil data id
 integer :: id

 !> tables cl(a,M) for each Re number
 type(t_aero_2d_tab) , allocatable :: aero_coeff(:)

end type t_aero_tab

!-----------------------------------

character(len=*), parameter :: this_mod_name='mod_c81'

contains

!-----------------------------------
! Vahana input file style '../vahana_input/vahana4.inp'
! HP: the aerodynamic coefficients are given for the same values
! of al_i, M_i
subroutine read_c81_table ( filen , coeff )
  character(len=max_char_len) , intent(in) :: filen
  type(t_aero_tab) , intent(inout) :: coeff

  character(len=max_char_len) :: line , string
  integer :: cl1 , cl2 , cd1 , cd2 , cm1 , cm2 !  table_dim(2)
  integer :: cp1(3) , cp2(3)
  real(wp) :: dummy
  integer :: dummy_int , iblnk
  integer :: fid , i1 , iRe , nRe , i_c
  real(wp) :: Re

  integer , parameter :: n_coeff = 3   ! cl , cd , cm

  ! Reynolds effect corrections ---
  real(wp) , parameter :: alMin = -5.0_wp , alMax = 5.0_wp
  integer :: iAl , iMa
  real(wp) :: al1 , al2 , c1 , c2
  integer :: ind_cl0 , istallp , istallm , stall_found
  ! Reynolds effect corrections ---

  fid = 21
  open(unit=fid,file=trim(adjustl(filen))) 
  ! First tree lines containing unintelligilbe parameters
  read(fid,*) nRe , dummy_int , dummy_int ! 2 0 0
  read(fid,*) ! 0 1
  read(fid,*) ! 0.158 0.158

  allocate( coeff%aero_coeff(nRe) )

  do iRe = 1 , nRe

    ! For each Reynolds number (1 Reynolds number, 3 coefficients)
    read(fid,*) ! COMMENT#1
    read(fid,*) Re  , dummy
    read(fid,'(A)') line
      iblnk = index(line,' ') 
      string = trim(adjustl(line(iblnk:)))
      read(string,'(6I2)') cl2 , cl1 , cd2 , cd1 , cm2 , cm1
      !                    NMa , Nal , NMa , Nal , NMa , Nal
    cp1 = (/ cl1 , cd1 , cm1 /)
    cp2 = (/ cl2 , cd2 , cm2 /)

    ! check that Reynolds number are defined in increasing order
    if ( iRe .gt. 1 ) then
      do i1 = 1 , iRe-1
        if ( coeff%aero_coeff(i1)%Re .ge. Re ) then
          write(*,*) ' in file: ' , trim(adjustl(filen)) , ' Reynolds nuber used to define'// &
                     ' .c81 tables must be in increasing order, but '
          write(*,*) ' -> Re(', iRe , '): ' , Re
          write(*,*) ' -> Re(', i1  , '): ' , coeff%aero_coeff(i1)%Re
          write(*,*) ' STOP ' // nl
          stop
        end if
      end do
    end if

    ! Reynolds number
    coeff%aero_coeff(iRe)%Re = Re
    allocate(coeff%aero_coeff(iRe)%coeff(n_coeff))
    ! allocate coefficient structures
    do i_c = 1 , n_coeff
      allocate(coeff%aero_coeff(iRe)%coeff(i_c)%par1(cp1(i_c)))
      allocate(coeff%aero_coeff(iRe)%coeff(i_c)%par2(cp2(i_c)))
      allocate(coeff%aero_coeff(iRe)%coeff(i_c)%cf(cp1(i_c),cp2(i_c)))
    end do

    do i_c = 1 , n_coeff
      read(fid,*) coeff%aero_coeff(iRe)%coeff(i_c)%par2   ! Mach numbers
      do i1 = 1 , cp1(i_c)
        read(fid,*) coeff%aero_coeff(iRe)%coeff(i_c)%par1(i1) , &    ! alpha
                    coeff%aero_coeff(iRe)%coeff(i_c)%cf(i1,:)        ! adim.coeff
      end do
    end do

    ! === table containing the partial derivative dCL/dalpha, ===
    ! === to be used in iterative processes                   ===
    ! 1st order finite difference at the extreme values of alpha, 2nd order for inner alphas
    allocate(coeff%aero_coeff(iRe)%dclda(cl1,cl2)) ! coeff1: cl

    coeff%aero_coeff(iRe)%dclda(1,:) = & 
      ( coeff%aero_coeff(iRe)%coeff(1)%cf(2,:) - coeff%aero_coeff(iRe)%coeff(1)%cf(1,:) ) / & 
      ( coeff%aero_coeff(iRe)%coeff(1)%par1(2) - coeff%aero_coeff(iRe)%coeff(1)%par1(1) )
    coeff%aero_coeff(iRe)%dclda(cl1,:) = & 
      ( coeff%aero_coeff(iRe)%coeff(1)%cf(cl1,:) - coeff%aero_coeff(iRe)%coeff(1)%cf(cl1-1,:) ) / & 
      ( coeff%aero_coeff(iRe)%coeff(1)%par1(cl1) - coeff%aero_coeff(iRe)%coeff(1)%par1(cl1-1) )
    do i1 = 2 , cl1-1 ! loop over par1: alpha
      coeff%aero_coeff(iRe)%dclda(i1,:) = & 
        ( coeff%aero_coeff(iRe)%coeff(1)%cf(i1+1,:) - coeff%aero_coeff(iRe)%coeff(1)%cf(i1-1,:) ) / & 
        ( coeff%aero_coeff(iRe)%coeff(1)%par1(i1+1) - coeff%aero_coeff(iRe)%coeff(1)%par1(i1-1) )
    end do

!   ! check ----
!   write(*,*) ' airfoil , Re ' , trim(filen) , coeff%aero_coeff(iRe)%Re
!   do i1 = 1 , cl1
!     write(*,*) coeff%aero_coeff(iRe)%dclda(i1,:)
!   end do
!   write(*,*)
!   ! check ----

    ! === Parameters for corrections for Reynolds number effects ===
    ! Find clmax, alcl0, cdmin for each (Re,M) 
    allocate(coeff%aero_coeff(iRe)%clmax(cl2)) ; coeff%aero_coeff(iRe)%clmax = -333.0_wp
    allocate(coeff%aero_coeff(iRe)%alcl0(cl2)) ; coeff%aero_coeff(iRe)%alcl0 = -333.0_wp
    allocate(coeff%aero_coeff(iRe)%cdmin(cd2)) ; coeff%aero_coeff(iRe)%cdmin = -333.0_wp
    allocate(coeff%aero_coeff(iRe)%clstall_pos(cd2)) ; coeff%aero_coeff(iRe)%clstall_pos = -333.0_wp
    allocate(coeff%aero_coeff(iRe)%clstall_neg(cd2)) ; coeff%aero_coeff(iRe)%clstall_neg = -333.0_wp
    allocate(coeff%aero_coeff(iRe)%alstall_pos(cd2)) ; coeff%aero_coeff(iRe)%alstall_pos = -333.0_wp
    allocate(coeff%aero_coeff(iRe)%alstall_neg(cd2)) ; coeff%aero_coeff(iRe)%alstall_neg = -333.0_wp

    do iMa = 1 , cl2

      ! --- clmax --- cl = coeff(1)
      coeff%aero_coeff(iRe)%clmax(iMa) = maxval( coeff%aero_coeff(iRe)%coeff(1)%cf(:,iMa) )

      ! --- al(cl=0) ---
      do iAl = 1 , cl1
        ! write(*,*) coeff%aero_coeff(iRe)%coeff(1)%par1(iAl) , alMin , alMax 
        if ( ( coeff%aero_coeff(iRe)%coeff(1)%par1(iAl) .ge. alMin ) .and. &
             ( coeff%aero_coeff(iRe)%coeff(1)%par1(iAl) .lt. alMax ) ) then
          if ( coeff%aero_coeff(iRe)%coeff(1)%cf(iAl  ,iMa) * & 
               coeff%aero_coeff(iRe)%coeff(1)%cf(iAl+1,iMa) .le. 0.0_wp ) then 
     
            al1 = coeff%aero_coeff(iRe)%coeff(1)%par1(iAl)
            al2 = coeff%aero_coeff(iRe)%coeff(1)%par1(iAl+1)
            c1  = coeff%aero_coeff(iRe)%coeff(1)%cf(iAl  ,iMa) 
            c2  = coeff%aero_coeff(iRe)%coeff(1)%cf(iAl+1,iMa)  

            coeff%aero_coeff(iRe)%alcl0(iMa) = al1 + (al2-al1) * (-c1)/(c2-c1)   

            ind_cl0 = iAl  ! index where cl changes sign: later used to find stall+ and stall- 

          end if 
        end if
      end do ! alpha

      ! --- cdmin --- cd = coeff(2)
      coeff%aero_coeff(iRe)%cdmin(iMa) = minval( coeff%aero_coeff(iRe)%coeff(2)%cf(:,iMa) )

      ! --- positive and negative stall: alpha and cl ---
      istallp = ind_cl0 ; istallm = ind_cl0
      ! positive stall
      stall_found = 0
      ! ---
      write(*,*) ' cl1 : ' , cl1
      write(*,*) ' shape(coeff%aero_coeff(',iRe,')%coeff(1)%cf) : ' , &
                   shape(coeff%aero_coeff(  iRe  )%coeff(1)%cf)
      do while ( ( istallp+1 .lt. cl1 ) .and. &
                 ( coeff%aero_coeff(iRe)%coeff(1)%cf(istallp+1,iMa) .gt. & 
                   coeff%aero_coeff(iRe)%coeff(1)%cf(istallp  ,iMa) ) .and. &
                 ( stall_found .eq. 0 ) &
                 ) 
        istallp = istallp + 1
        
!       ! ---- check the "second derivative" ( high Ma cl(alpha) ) ----
!       if ( coeff%aero_coeff(iRe)%coeff(1)%cf(istallp+1,iMa) .gt. &
!         coeff%aero_coeff(iRe)%coeff(1)%cf(  istallp  ,iMa) + & 
!        (coeff%aero_coeff(iRe)%coeff(1)%cf(  istallp+2,iMa) - &
!         coeff%aero_coeff(iRe)%coeff(1)%cf(  istallp  ,iMa) ) * & 
!        (coeff%aero_coeff(iRe)%coeff(1)%par1(istallp+1) - &
!         coeff%aero_coeff(iRe)%coeff(1)%par1(istallp  ) ) / & 
!        (coeff%aero_coeff(iRe)%coeff(1)%par1(istallp+2) - &
!         coeff%aero_coeff(iRe)%coeff(1)%par1(istallp  ) ) &
!             ) then  ! check the "second derivative" ( high Ma cl(alpha) )
!         stall_found = 1
!       end if

      end do
      ! negative stall
      stall_found = 0
      do while ( ( istallm-1 .gt. 1 ) .and. &
                 ( coeff%aero_coeff(iRe)%coeff(1)%cf(istallm-1,iMa) .lt. & 
                   coeff%aero_coeff(iRe)%coeff(1)%cf(istallm  ,iMa) ) .and. &
                 ( stall_found .eq. 0 ) ) 
        istallm = istallm - 1
        
!       ! ---- check the "second derivative" ( high Ma cl(alpha) ) ----
!       if ( coeff%aero_coeff(iRe)%coeff(1)%cf(istallp-1,iMa) .lt. &
!         coeff%aero_coeff(iRe)%coeff(1)%cf(  istallp  ,iMa) + &
!        (coeff%aero_coeff(iRe)%coeff(1)%cf(  istallp-2,iMa) - &
!         coeff%aero_coeff(iRe)%coeff(1)%cf(  istallp  ,iMa) ) * & 
!        (coeff%aero_coeff(iRe)%coeff(1)%par1(istallp-1) - &
!         coeff%aero_coeff(iRe)%coeff(1)%par1(istallp  ) ) / & 
!        (coeff%aero_coeff(iRe)%coeff(1)%par1(istallp-2) - &
!         coeff%aero_coeff(iRe)%coeff(1)%par1(istallp  ) ) &
!             ) then
!         stall_found = 1
!       end if
        
      end do

      coeff%aero_coeff(iRe)%alstall_pos(iMa) = coeff%aero_coeff(iRe)%coeff(1)%par1(istallp)
      coeff%aero_coeff(iRe)%alstall_neg(iMa) = coeff%aero_coeff(iRe)%coeff(1)%par1(istallm)
      coeff%aero_coeff(iRe)%clstall_pos(iMa) = coeff%aero_coeff(iRe)%coeff(1)%cf(istallp,iMa)
      coeff%aero_coeff(iRe)%clstall_neg(iMa) = coeff%aero_coeff(iRe)%coeff(1)%cf(istallm,iMa)

    end do ! Mach number
    ! === Parameters for corrections for Reynolds number effects ===

  end do ! Reynolds number

  close(fid)

end subroutine read_c81_table

!-----------------------------------
!> Routine to compute aerodynamic coefficients,
!>  given the geometry ( airfoil_data, csi , airfoil_id) and
!>        the aerodynamic parameters( aero_par = (/ al , M , Re /)

! TODO: add some checks : if reyn1 .eq. reyn2 to avoid singularity
!       clear implementation
!       ...
subroutine interp_aero_coeff ( airfoil_data ,  &
                         csi , airfoil_id , aero_par , aero_coeff , &
                         dclda )
  type(t_aero_tab) , intent(in) :: airfoil_data(:)
  real(wp) , intent(in) :: csi
  integer  , intent(in) :: airfoil_id(2)
  real(wp) , intent(in) :: aero_par(3) ! (/al,M,Re/)
  real(wp) , allocatable , intent(out) :: aero_coeff(:) 
  real(wp)               , intent(out) :: dclda

  real(wp) :: al , mach , reyn
  real(wp) :: cf1(3) , cf2(3)
  real(wp) , allocatable :: coeff1(:) , coeff2(:)
  real(wp) , allocatable :: coeff_airfoil(:,:) 
  integer :: nRe, i_a, id_a

  real(wp) :: reyn1 , reyn2
  integer  :: irey

  ! Reynolds effect correction ----
  real(wp) :: k_fact
  real(wp) , parameter :: n_fact = 0.2_wp ! Now hard-coded. TODO: read as an input
  real(wp) :: aero_par_re(2)
  integer :: nmach , imach
  real(wp) :: machend , mach1 , mach2 , al0
  ! Reynolds effect correction ----

  ! dclda ----
  real(wp) :: dclda1 , dclda2
  real(wp) :: dclda_v(2)
  ! dclda ----

  al   = aero_par(1)
  mach = aero_par(2)
  reyn = aero_par(3)

  cf1 = 0.0_wp
  cf2 = 0.0_wp

  ! new: taking into account Reynolds effects
  ! old version of the code at the end of this file
  do i_a = 1 , 2

    id_a = airfoil_id(i_a)
    nRe = size(airfoil_data(id_a)%aero_coeff)
  
    if ( reyn .le. airfoil_data(id_a)%aero_coeff( 1 )%Re ) then
      ! --- Reynolds effects with semi-empirical laws ---
      irey = 1
      k_fact = ( reyn / airfoil_data(id_a)%aero_coeff(irey)%Re ) ** n_fact

      ! ! debug ----
      ! write(*,*) ' k_fact : ' , k_fact
      ! ! debug ----

      ! aero_par taking into account the Reynolds effect:
      ! --- find al(cl=0), for the desired mach number ---
      nmach = size(airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2)
      imach = 1 
      mach1   = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(imach)
      machend = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(nmach)
      do while ( (  mach .ge. mach1 ) .and. & 
                 ( imach .lt. nmach  ) )
        imach = imach + 1
        mach1 = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(imach)
      end do
      imach = imach - 1
      mach1 = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(imach)
      mach2 = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(imach+1)

      al0 = airfoil_data(id_a)%aero_coeff(irey)%alcl0(imach) + &
            (mach-mach1)/(mach2-mach1) * &
           ( airfoil_data(id_a)%aero_coeff(irey)%alcl0(imach+1) - &
             airfoil_data(id_a)%aero_coeff(irey)%alcl0(imach  ) )

      ! --- correct alpha ---
      aero_par_re    = aero_par(1:2)
      aero_par_re(1) = ( aero_par(1) - al0 ) / k_fact + al0
      call interp2d_aero_coeff ( airfoil_data(id_a)%aero_coeff(irey)%coeff , &
                                 airfoil_data(id_a)%aero_coeff(irey)%dclda , &
                                                   aero_par_re , coeff1    , &
                                                   dclda1 )
      ! --- correct cl, cd ---
      coeff1(1) = coeff1(1) * k_fact
      coeff1(2) = coeff1(2) / k_fact  ! cd correction

      if ( .not. allocated(coeff_airfoil) )  allocate(coeff_airfoil(2,size(coeff1)))
      coeff_airfoil(i_a,:) = coeff1
      dclda_v(i_a) = dclda1 * k_fact

    else if ( reyn .ge. airfoil_data(id_a)%aero_coeff(nRe)%Re ) then
      ! --- Reynolds effects with semi-empirical laws ---
      irey = nRe
      k_fact = ( reyn / airfoil_data(id_a)%aero_coeff(irey)%Re ) ** n_fact

      ! aero_par taking into account the Reynolds effect:
      ! --- find al(cl=0), for the desired mach number ---
      nmach = size(airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2)
      imach = 1 
      mach1   = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(imach)
      machend = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(nmach)
      do while ( (  mach .ge. mach1 ) .and. & 
                 ( imach .lt. nmach  ) )
        imach = imach + 1
        mach1 = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(imach)
      end do
      imach = imach - 1
      mach1 = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(imach)
      mach2 = airfoil_data(id_a)%aero_coeff(irey)%coeff(1)%par2(imach+1)

      al0 = airfoil_data(id_a)%aero_coeff(irey)%alcl0(imach) + &
            (mach-mach1)/(mach2-mach1) * &
           ( airfoil_data(id_a)%aero_coeff(irey)%alcl0(imach+1) - &
             airfoil_data(id_a)%aero_coeff(irey)%alcl0(imach  ) )

      ! --- correct alpha ---
      aero_par_re    = aero_par(1:2)
      aero_par_re(1) = ( aero_par(1) - al0 ) / k_fact + al0
      call interp2d_aero_coeff ( airfoil_data(id_a)%aero_coeff(irey)%coeff , &
                                 airfoil_data(id_a)%aero_coeff(irey)%dclda , &
                                                   aero_par_re , coeff1    , &
                                                   dclda1 )
      ! --- correct cl, cd ---
      coeff1(1) = coeff1(1) * k_fact
      coeff1(2) = coeff1(2) / k_fact  ! cd correction

      if ( .not. allocated(coeff_airfoil) )  allocate(coeff_airfoil(2,size(coeff1)))
      coeff_airfoil(i_a,:) = coeff1
      dclda_v(i_a) = dclda1 * k_fact

    else 
      ! --- linear interpolation ---
      ! find the smallest range of Re in tables including the desired Re
      irey  = 1
      reyn1 = airfoil_data(id_a)%aero_coeff(irey)%Re 
      do while ( ( reyn .ge. reyn1 ) .and. ( irey .lt. nRe ) )
        irey = irey + 1
        reyn1 = airfoil_data(id_a)%aero_coeff(irey)%Re 
      end do
      irey = irey - 1
      reyn1 = airfoil_data(id_a)%aero_coeff(irey)%Re 
      reyn2 = airfoil_data(id_a)%aero_coeff(irey+1)%Re 
 
      call interp2d_aero_coeff ( airfoil_data(id_a)%aero_coeff(irey)%coeff , &
                                 airfoil_data(id_a)%aero_coeff(irey)%dclda , &
                                                   aero_par(1:2) , coeff1  , &
                                                   dclda1 )
      call interp2d_aero_coeff ( airfoil_data(id_a)%aero_coeff(irey+1)%coeff , &
                                 airfoil_data(id_a)%aero_coeff(irey+1)%dclda , &
                                                   aero_par(1:2) , coeff2    , &
                                                   dclda2 )
 
      if ( .not. allocated(coeff_airfoil) )  allocate(coeff_airfoil(2,size(coeff1)))
 
      coeff_airfoil(i_a,:) = ( coeff1 * ( reyn2 - reyn ) + coeff2 * ( reyn - reyn1 ) ) /  &
                             ( reyn2 - reyn1 ) 
      dclda_v(i_a) = ( dclda1 * ( reyn2 - reyn ) + dclda2 * ( reyn - reyn1 ) ) /  &
                     ( reyn2 - reyn1 ) 
    end if

  end do

  allocate( aero_coeff(size(coeff_airfoil,2)) )
  aero_coeff = coeff_airfoil(1,:) * ( 1.0_wp-csi ) + coeff_airfoil(2,:) * csi
  dclda = dclda_v(1) * (1.0_wp-csi) + dclda_v(2)*csi

  ! deallocate
  deallocate(coeff_airfoil)


end subroutine interp_aero_coeff 

!-----------------------------------
! 
subroutine interp2d_aero_coeff ( aero_coeff , dclda , x , c , dcl )
 type(t_aero_2d_par) , intent(in) :: aero_coeff(:)
 real(wp)            , intent(in) :: dclda(:,:)
 real(wp), intent(in)  :: x(:)     ! aero_par (al,M,Re)
 real(wp), allocatable , intent(out) :: c(:)
 real(wp),               intent(out) :: dcl 

 integer  :: n1 , n2 , nc
 real(wp) :: csi1 , csi2
 real(wp) :: phi1 , phi2 , phi3 , phi4

 integer :: ic , i1 , i2

 character(len=*), parameter :: this_sub_name='interp2d_aero_coeff'


 
 nc = size(aero_coeff)

 allocate(c(nc)) ; c = 0.0_wp

 ! only 2d parameters are allowed (al,M)
 if ( size(x) .ne. 2 ) then 
   call error(this_sub_name, this_mod_name, 'Attempting to 2D interpolate&
   & data with more dimensions')
 end if

 ! Do it once ...
 ! Check dimensions ---------
 do ic = 1 , nc

   n1 = size(aero_coeff(ic)%par1)
   n2 = size(aero_coeff(ic)%par2)

!  ! DEBUG
!  write(*,*) ' n1 , n2 : ' , n1 , n2

   if ( size(aero_coeff(ic)%cf,1) .ne. n1 ) then
     write(*,*) ' Error in interp2d. '
     write(*,*) ' size(coeff(',ic,')%Mat,1) .ne. ', n1,'. STOP. ' ; stop
   end if
   if ( size(aero_coeff(ic)%cf,2) .ne. n2 ) then
     write(*,*) ' Error in interp2d. '
     write(*,*) ' size(coeff(',ic,')%Mat,2) .ne. n2. STOP. ' ; stop
   end if

   ! Check range of parameters the parameters are supposed to be defined in an
   ! increasing order
   if ( x(1) .lt. aero_coeff(ic)%par1(1) ) then
     write(*,*) ' x(1) : ' , x(1)
     write(*,*) ' ic   : ' , ic , ' 1:cl, 2:cd, 3:cm '
     write(*,*) ' minval(aero_ceoff(ic)%par1) : ' , aero_coeff(ic)%par1(1) , ' par1: Mach number '
     write(*,*) ' check .c81 input files ' 
     write(*,*) ' Error in interp2d. x(1) .lt. minval(aero_coeff(ic)%par1). STOP' ; stop
   end if
   if ( x(1) .gt. aero_coeff(ic)%par1(n1) ) then
     write(*,*) ' x(1) : ' , x(1)
     write(*,*) ' ic   : ' , ic , ' 1:cl, 2:cd, 3:cm '
     write(*,*) ' maxval(aero_ceoff(ic)%par1) : ' , aero_coeff(ic)%par1(n1) , ' par1: Mach number '
     write(*,*) ' check .c81 input files ' 
     write(*,*) ' Error in interp2d. x(1) .gt. maxval(aero_coeff(ic)%par1). STOP' ; stop
   end if
   if ( x(2) .lt. aero_coeff(ic)%par2(1) ) then
     write(*,*) ' x(2) : ' , x(2)
     write(*,*) ' ic   : ' , ic , ' 1:cl, 2:cd, 3:cm '
     write(*,*) ' minval(aero_ceoff(ic)%par2) : ' , aero_coeff(ic)%par2(1) , ' par2: alpha angle '
     write(*,*) ' check .c81 input files ' 
     write(*,*) ' Error in interp2d. x(2) .lt. minval(aero_coeff(ic)%par2). STOP' ; stop
   end if
   if ( x(2) .gt. aero_coeff(ic)%par2(n2) ) then
     write(*,*) ' x(2) : ' , x(2)
     write(*,*) ' ic   : ' , ic , ' 1:cl, 2:cd, 3:cm '
     write(*,*) ' maxval(aero_ceoff(ic)%par2) : ' , aero_coeff(ic)%par2(n2) , ' par2: alpha angle '
     write(*,*) ' check .c81 input files ' 
     write(*,*) ' Error in interp2d. x(2) .gt. maxval(aero_coeff(ic)%par2). STOP'
     write(*,*) aero_coeff(ic)%par2(:)
     stop
   end if
   ! Check dimensions ---------

   i1 = 1 
   do while ( (aero_coeff(ic)%par1(i1) .le. x(1)) ) 
     i1 = i1 + 1 
   end do
   i2 = 1 
   do while ( (aero_coeff(ic)%par2(i2) .le. x(2)) ) 
     i2 = i2 + 1 
   end do
  
   csi1 = 2.0_wp * ( x(1) - 0.5_wp*(aero_coeff(ic)%par1(i1-1)+aero_coeff(ic)%par1(i1)) ) / &
         (aero_coeff(ic)%par1(i1)-aero_coeff(ic)%par1(i1-1))

   csi2 = 2.0_wp * ( x(2) - 0.5_wp*(aero_coeff(ic)%par2(i2-1)+aero_coeff(ic)%par2(i2)) ) / &
         (aero_coeff(ic)%par2(i2)-aero_coeff(ic)%par2(i2-1))
  
   phi1 =   0.25_wp * ( 1 + csi1 ) * ( 1 + csi2 )
   phi2 =   0.25_wp * ( 1 - csi1 ) * ( 1 + csi2 )
   phi3 =   0.25_wp * ( 1 - csi1 ) * ( 1 - csi2 )
   phi4 =   0.25_wp * ( 1 + csi1 ) * ( 1 - csi2 )
  
   c(ic) = phi1 * aero_coeff(ic)%cf(i1  ,i2  ) + &
           phi2 * aero_coeff(ic)%cf(i1-1,i2  ) + &
           phi3 * aero_coeff(ic)%cf(i1-1,i2-1) + &
           phi4 * aero_coeff(ic)%cf(i1  ,i2-1)

   if ( ic .eq. 1 ) then ! interpolate dclda (defined only where ic=1, i.e. coeff=cl)
     dcl = phi1 * dclda(i1  ,i2  ) + &
           phi2 * dclda(i1-1,i2  ) + &
           phi3 * dclda(i1-1,i2-1) + &
           phi4 * dclda(i1  ,i2-1)
   end if

 end do 




!  i1 = 1 
!  do while ( (x1(i1) .lt. x(1)) ) 
!    i1 = i1 + 1 
!  end do
!  i2 = 1 
!  do while ( (x2(i2) .lt. x(2)) ) 
!    i2 = i2 + 1 
!  end do
! 
!  csi1 = 2.0_wp * ( x(1) - 0.5_wp*(x1(i1-1)+x1(i1)) ) / (x1(i1)+x1(i1-1))
!  csi2 = 2.0_wp * ( x(2) - 0.5_wp*(x2(i2-1)+x2(i2)) ) / (x2(i2)+x2(i2-1))
! 
!  phi1 =   0.25_wp * ( 1 + csi1 ) * ( 1 + csi2 )
!  phi2 =   0.25_wp * ( 1 - csi1 ) * ( 1 + csi2 )
!  phi3 =   0.25_wp * ( 1 - csi1 ) * ( 1 - csi2 )
!  phi4 =   0.25_wp * ( 1 + csi1 ) * ( 1 - csi2 )
! 
!  allocate(c(nc)) ; c = 0.0_wp
!  do ic = 1 , nc
!    c(ic) = phi1 * coeff(ic)%Mat(i1  ,i2  ) + &
!            phi2 * coeff(ic)%Mat(i1-1,i2  ) + &
!            phi3 * coeff(ic)%Mat(i1-1,i2-1) + &
!            phi4 * coeff(ic)%Mat(i1  ,i2-1)
!  end do

end subroutine interp2d_aero_coeff

!-----------------------------------


end module mod_c81




! ! --- old --------------
!   ! Find the aerodynamic profiles to be interpolated in order to obtain
!   ! the aerodynamic characteristics of the wing section
!   do i_a = 1 , 2
! 
!    id_a = airfoil_id(i_a)
!    nRe = size(airfoil_data(id_a)%aero_coeff)
!   
!    ! Some checks ----
!    if ( nRe .eq. 1 ) then ! .c81 defined just for one Reynolds number
! 
!      call interp2d_aero_coeff ( airfoil_data(id_a)%aero_coeff(1)%coeff , &
!                                                   aero_par(1:2) , coeff1 )
! 
!      if ( .not. allocated(coeff_airfoil) ) then
!        allocate(coeff_airfoil(2,size(coeff1)))
!      end if
! 
!      coeff_airfoil(i_a,:) = coeff1
! 
!    else ! .c81 defined for more than one Reynolds number 
! 
!      ! Some checks ----
!      if ( reyn .lt. airfoil_data(id_a)%aero_coeff(1)%Re ) then
!        reyn1 = airfoil_data(id_a)%aero_coeff(1)%Re
!        reyn2 = airfoil_data(id_a)%aero_coeff(2)%Re
!        irey  = 1
!      else if ( reyn .gt. airfoil_data(id_a)%aero_coeff(nRe)%Re ) then
!        reyn1 = airfoil_data(id_a)%aero_coeff(nRe-1)%Re
!        reyn2 = airfoil_data(id_a)%aero_coeff(nRe)%Re
!        irey  = nRe-1
!      else
! 
!        irey  = 1
!        reyn1 = airfoil_data(id_a)%aero_coeff(irey)%Re
!        do while ( ( reyn .ge. reyn1 ) .and. ( irey .lt. nRe ) )
!          irey = irey + 1
!          reyn1 = airfoil_data(id_a)%aero_coeff(irey)%Re 
!        end do
!        irey = irey - 1
!        reyn1 = airfoil_data(id_a)%aero_coeff(irey)%Re 
!        reyn2 = airfoil_data(id_a)%aero_coeff(irey+1)%Re 
! 
!      end if
!      ! Some checks ----
! 
!      call interp2d_aero_coeff ( airfoil_data(id_a)%aero_coeff(irey)%coeff , &
!                                                   aero_par(1:2) , coeff1 )
!      call interp2d_aero_coeff ( airfoil_data(id_a)%aero_coeff(irey+1)%coeff , &
!                                                   aero_par(1:2) , coeff2 )
! 
!      if ( .not. allocated(coeff_airfoil) ) then
!        allocate(coeff_airfoil(2,size(coeff1)))
!      end if
! 
!      coeff_airfoil(i_a,:) = ( coeff1 * ( reyn2 - reyn ) + coeff2 * ( reyn - reyn1 ) ) /  &
!                             ( reyn2 - reyn1 ) 
! 
!    end if
! 
!   end do
! ! --- old --------------

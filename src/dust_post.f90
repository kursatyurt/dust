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

program dust_post

use mod_param, only: &
  wp, nl, max_char_len, extended_char_len , pi

use mod_handling, only: &
  error, warning, info, printout, dust_time, t_realtime

use mod_geometry, only: &
  t_geo, t_geo_component

use mod_basic_io, only: &
  read_mesh_basic, write_basic

use mod_aero_elements, only: &
  c_elem, t_elem_p!, t_vp

!this is for the parsing
use mod_parse, only: &
  t_parse, &
  getstr, getlogical, getreal, getint, &
  getrealarray, getintarray , &
  ignoredParameters, finalizeParameters, &
  countoption, getsuboption, t_link, check_opt_consistency, &
  print_parse_debug

use mod_build_geo, only: &
  build_geometry

use mod_hdf5_io, only: &
  initialize_hdf5, destroy_hdf5, &
   h5loc, &
   new_hdf5_file, &
   open_hdf5_file, &
   close_hdf5_file, &
   new_hdf5_group, &
   open_hdf5_group, &
   close_hdf5_group, &
   write_hdf5, &
   read_hdf5, &
   read_hdf5_al, &
   check_dset_hdf5

use mod_stringtools, only: &
  LowCase, isInList

use mod_geo_postpro, only: &
  load_components_postpro, update_points_postpro , prepare_geometry_postpro, &
  expand_actdisk_postpro, prepare_wake_postpro

use mod_wake_pan, only: &
  t_wake_panels

use mod_tecplot_out, only: &
  tec_out_viz

use mod_vtk_out, only: &
  vtk_out_viz , vtr_write

use mod_dat_out, only: & 
  dat_out_probes_header , dat_out_probes 

use mod_actuatordisk, only: &
  t_actdisk

implicit none

!Input
character(len=*), parameter :: input_file_name_def = 'dust_post.in' 
character(len=max_char_len) :: input_file_name

!Geometry parameters
type(t_parse) :: prms
type(t_parse), pointer :: sbprms

integer :: n_analyses, ia

character(len=max_char_len) :: basename, data_basename
character(len=max_char_len) :: an_name, an_type
integer :: an_start, an_end, an_step
integer :: n_comp, i_comp
character(len=max_char_len), allocatable :: components_names(:)
integer :: n_var, i_var
character(len=max_char_len), allocatable :: var_names(:)
character(len=max_char_len) :: lowstr
character(len=max_char_len) :: filename
character(len=max_char_len) :: out_frmt
logical :: all_comp
logical :: out_vort, out_vel, out_cp, out_press
logical :: out_wake

integer(h5loc) :: floc, geo_floc, gloc1, gloc2 , ploc

real(wp), allocatable :: points(:,:), points_exp(:,:)
integer, allocatable :: elems(:,:)
type(t_geo_component), allocatable :: comps(:)
integer :: nelem, nelem_out

real(wp), allocatable :: refs_R(:,:,:), refs_off(:,:)
real(wp), allocatable :: vort(:), cp(:)
real(wp), allocatable :: wvort(:), wvort_pan(:,:), wpoints(:,:), wpoints_pan(:,:,:)
integer,  allocatable :: welems(:,:)
integer, allocatable  :: wstart(:,:)
integer :: nelem_w
real(wp) :: t

real(wp), allocatable :: print_vars(:,:)
character(len=max_char_len), allocatable :: print_var_names(:)
real(wp), allocatable :: print_vars_w(:,:)
character(len=max_char_len), allocatable :: print_var_names_w(:)
integer :: nprint, ivar

integer, allocatable :: print_elems(:,:)

! wake ------------
type(t_wake_panels) :: wake

! probe output ----
character(len=max_char_len) :: in_type , str_a , filename_in , var_name
integer :: n_probes , n_vars , n_vars_int
real(wp), allocatable :: rr_probes(:,:)
logical :: probe_vel , probe_p , probe_vort
character(len=max_char_len) :: vars_str
! real(wp) , allocatable :: u_inf(:)
real(wp) :: u_inf(3)
real(wp) :: P_inf , rho
real(wp) :: vel_probe(3) = 0.0_wp , vort_probe(3) = 0.0_wp 
real(wp) :: v(3) = 0.0_wp , w(3) = 0.0_wp
real(wp), allocatable , target :: sol(:) 
real(wp) :: pres_probe
integer :: fid_out , ip , ie, ic
! flow field ------
integer :: nxyz(3)
real(wp):: minxyz(3) , maxxyz(3)
real(wp), allocatable :: xbox(:) , ybox(:) , zbox(:)
real(wp) :: dxbox , dybox , dzbox
real(wp), allocatable :: box_vel(:,:) , box_p(:) , box_vort(:,:)
integer :: ix , iy , iz
integer , allocatable :: vars_n(:)
character(len=max_char_len) , allocatable :: vars_name(:)
real(wp), allocatable :: vars(:,:) 
integer :: i_vars , i_var_v , i_var_p , i_var_w

integer :: it , i1


!write(*,*) 'DUST beginning'
call printout(nl//'>>>>>> DUST POSTPROCESSOR beginning >>>>>>'//nl)
call initialize_hdf5()

!------ Input reading ------

if(command_argument_count().gt.0) then                                         
  call get_command_argument(1,value=input_file_name)                           
else                                                                           
  input_file_name = input_file_name_def                                        
endif   

call prms%CreateStringOption('basename','Base name of the processed data')
call prms%CreateStringOption('data_basename','Base name of the data to be &
                              &processed')
call prms%CreateSubOption('Analysis','Definition of the motion of a frame', &
                          sbprms, multiple=.true.)
call sbprms%CreateStringOption('Type','type of analysis')
call sbprms%CreateStringOption('Name','specification of the analysis')
call sbprms%CreateIntOption('StartRes', 'Starting result of the analysis')
call sbprms%CreateIntOption('EndRes', 'Final result of the analysis')
call sbprms%CreateIntOption('StepRes', 'Result stride of the analysis')
call sbprms%CreateLogicalOption('Wake', 'Output also the wake for &
                                &visualization','T')
call sbprms%CreateStringOption('Format','Output format')
call sbprms%CreateStringOption('Component','Component to analyse', &
                               multiple=.true.)
call sbprms%CreateStringOption('Var','Variable to analise', &
                               multiple=.true.)

! probe output -------------
call sbprms%CreateStringOption('InputType','How to specify probe coordinates',&
                              multiple=.true.)
call sbprms%CreateRealArrayOption('Point','Point coordinates in dust_post.in',&
                              multiple=.true.)
call sbprms%CreateStringOption('File','File containing the coordinates of the probes',&
                              multiple=.true.)
call sbprms%CreateStringOption('Variable','Variables to be saved: velocity, pressure or&
                              & vorticity', multiple=.true.)
! flow field output --------
call sbprms%CreateIntArrayOption( 'Nxyz','number of points per coordinate',&
                              multiple=.true.)
call sbprms%CreateRealArrayOption('Minxyz','lower bounds of the box',&
                              multiple=.true.)
call sbprms%CreateRealArrayOption('Maxxyz','upper bounds of the box',&
                              multiple=.true.)


sbprms=>null()

call prms%read_options(input_file_name, printout_val=.false.)

basename = getstr(prms,'basename')
data_basename = getstr(prms,'data_basename')
n_analyses = countoption(prms,'Analysis')

!Cycle on all the analyses
do ia = 1,n_analyses
  
  !Get some of the options
  call getsuboption(prms,'Analysis',sbprms)
  an_type  = getstr(sbprms,'Type')
  call LowCase(an_type)
  an_name  = getstr(sbprms,'Name')
  out_frmt = getstr(sbprms,'Format')
  call LowCase(out_frmt)
  an_start = getint(sbprms,'StartRes')
  an_end   = getint(sbprms,'EndRes')
  an_step  = getint(sbprms,'StepRes')
 
  !Check if we are analysing all the components or just some
  all_comp = .false.
  n_comp = countoption(sbprms, 'Component')
  if (n_comp .eq. 0)  then
    all_comp = .true.
  else
    allocate(components_names(n_comp))
    do i_comp = 1, n_comp
      components_names(i_comp) = getstr(sbprms, 'Component')
    enddo
    call LowCase(components_names(1),lowstr)
    if(trim(lowstr) .eq. 'all') then
      all_comp = .true.
    endif
  endif

  !Check which variables to analyse
  out_vort = .false.; out_vel = .false.; out_press =.false.; out_cp = .false.
  n_var = countoption(sbprms, 'Var')
  allocate(var_names(n_var))
  do i_var = 1, n_var 
    var_names(i_var) = getstr(sbprms, 'Var')
  enddo
  out_vort = isInList('vort',var_names)
  out_vel = isInList('vel',var_names)
  out_press = isInList('press',var_names)
  out_cp = isInList('cp',var_names)

  !Fork the different kind of analyses
  select case(trim(an_type))

   !//////////////////Visualizations\\\\\\\\\\\\\\\\\
   case('viz') 

    ! load the geo components just once just once
    call open_hdf5_file(trim(data_basename)//'_geo.h5', floc)
    !TODO: here get the run id
    call load_components_postpro(comps, points, nelem, floc, & 
                                 components_names,  all_comp)
    call close_hdf5_file(floc)
    out_wake = getlogical(sbprms,'Wake')

    ! Prepare_geometry_postpro
    call prepare_geometry_postpro(comps)


    !time history
    do it =an_start, an_end, an_step

      ! Open the file:
      write(filename,'(A,I4.4,A)') trim(data_basename)//'_res_',it,'.h5'
      call open_hdf5_file(trim(filename),floc)

      ! Load u_inf
      call open_hdf5_group(floc,'Parameters',ploc)
      call read_hdf5(u_inf,'u_inf',ploc)
      call read_hdf5(P_inf,'P_inf',ploc)
      call read_hdf5(rho,'rho_inf',ploc)
      call close_hdf5_group(ploc)


      ! Load the references
      call load_refs(floc,refs_R,refs_off)

      ! Move the points
      call update_points_postpro(comps, points, refs_R, refs_off)
      !expand the actuator disks
      call expand_actdisk_postpro(comps, points, points_exp, elems)

      !Load the results
      call load_res(floc, comps, vort, cp, t)

      !Prepare the variable for output
      nelem_out = size(vort)
      nprint = 0
      if(out_vort) nprint = nprint+1
      if(out_cp)   nprint = nprint+1
      allocate(print_var_names(nprint), print_vars(nelem_out, nprint))
      
      ivar = 1
      if(out_vort) then
        print_vars(:,ivar) = vort
        print_var_names(ivar) = 'Vorticity'
        ivar = ivar +1
      endif
      if(out_cp) then
        print_vars(:,ivar) = cp
        print_var_names(ivar) = 'Cp'
        ivar = ivar +1
      endif

      write(filename,'(A,I4.4)') trim(basename)//'_'//trim(an_name)//&
                                                            '_',it
      
      if (out_wake) then

        !!Load the wake
        !call load_wake_pan(floc, wpoints, wstart, wvort)
        !!Prepare the wake variables for output
        !nstripes = size(wvort,1); nstripes_p = size(wpoints,2)
        !nrows = size(wvort,2); nelem_w = nstripes*nrows
        !allocate(wpoints_s(3,nstripes_p*(nrows+1)))
        !allocate(welems(4,nelem_w))
        !wpoints_s = reshape(wpoints, (/3,nstripes_p*(nrows+1)/))
        !iew = 0
        !do ir = 1,nrows
        !  do is = 1,nstripes
        !    iew = iew+1
        !    welems(:,iew) = (/wstart(1,is)+nstripes_p*(ir-1), &
        !                      wstart(2,is)+nstripes_p*(ir-1), &
        !                      wstart(2,is)+nstripes_p*(ir), &
        !                      wstart(1,is)+nstripes_p*(ir)/)
        !  enddo
        !enddo
        
        call load_wake_viz(floc, wpoints, welems, wvort)
        nelem_w = size(welems,2)

        nprint = 0
        if(out_vort) nprint = nprint+1
        allocate(print_var_names_w(nprint), print_vars_w(nelem_w, nprint))
        
        ivar = 1
        if(out_vort) then
          !print_vars_w(:,ivar) = reshape(wvort,(/nelem_w/))
          print_vars_w(:,ivar) = wvort
          print_var_names_w(ivar) = 'Vorticity'
          ivar = ivar +1
        endif

        !Output the results (with wake)
        !DEBUG
        write(*,*) ' trim(out_frmt) : ' , trim(out_frmt)
        select case (trim(out_frmt))
         case ('tecplot')
          filename = trim(filename)//'.plt'
          call  tec_out_viz(filename, t, &
                       points_exp, elems, print_vars, print_var_names, &
                       w_rr=wpoints, w_ee=welems, w_vars=print_vars_w, &
                       w_var_names = print_var_names_w)
         case ('vtk')
          filename = trim(filename)//'.vtu'
          call  vtk_out_viz(filename, &
                       points_exp, elems, print_vars, print_var_names, &
                       w_rr=wpoints, w_ee=welems, w_vars=print_vars_w, &
                       w_var_names = print_var_names_w)
         case default
           call error('dust_post','','Unknown format '//trim(out_frmt)//&
                      ' for visualization output')
         end select
      
        deallocate (wpoints, welems,  wvort)
        deallocate(print_var_names_w, print_vars_w)

      else
        
        !Output the results (without wake)
        select case (trim(out_frmt))
         case ('tecplot')
          filename = trim(filename)//'.plt'
          call  tec_out_viz(filename, t, &
                       points_exp, elems, print_vars, print_var_names)
         case ('vtk')
          filename = trim(filename)//'.vtu'
          call  vtk_out_viz(filename, &
                       points_exp, elems, print_vars, print_var_names)
         case default
           call error('dust_post','','Unknown format '//trim(out_frmt)//&
                      ' for visualization output')
         end select

      endif

      call close_hdf5_file(floc)
      deallocate(refs_R, refs_off, vort, cp)
      deallocate(print_var_names, print_vars)

    enddo !Time history

    deallocate(comps, points)


   !//////////////////Domain probes \\\\\\\\\\\\\\\\\
   case('probes')

    ! Read probe coordinates: point_list or from_file
    in_type =  getstr(sbprms,'InputType')
    select case ( trim(in_type) )
     case('point_list')
      n_probes = countoption(sbprms,'Point')
      allocate(rr_probes(3,n_probes))
      do ip = 1 , n_probes
        rr_probes(:,ip) = getrealarray(sbprms,'Point',3)
      end do
     case('from_file')
      filename_in = getstr(sbprms,'File')   ! N probes and then their coordinates
      fid_out = 21
      open(unit=fid_out,file=trim(filename_in))
      read(fid_out,*) n_probes
      allocate(rr_probes(3,n_probes))
      do ip = 1 , n_probes
        read(fid_out,*) rr_probes(:,ip)
      end do
      close(fid_out)
     case default
      write(str_a,*) ia 
      call error('dust_post','','Unknown InputType: '//trim(in_type)//&
                 ' for analysis n.'//trim(str_a)//'.'//nl//&
                  'It must either "point_list" or "from_file".')
    end select

    ! Read variables to save : velocity | pressure | vorticity
    probe_vel = .false. ; probe_p = .false. ; probe_vort = .false.
    n_vars = countoption(sbprms,'Variable')

    if ( n_vars .eq. 0 ) then ! default: velocity | pressure | vorticity
      probe_vel = .true. ; probe_p = .true. ; probe_vort = .true.
    else
     do it = 1 , n_vars
      var_name = getstr(sbprms,'Variable')
      select case(trim(var_name))
       case ( 'velocity' ) ; probe_vel = .true.
       case ( 'pressure' ) ; probe_p   = .true.
       case ( 'vorticity') ; probe_vort= .true.
       case ( 'all') ; probe_vel = .true. ; probe_p   = .true. ; probe_vort= .true.
       case default
       call error('dust_post','','Unknown Variable: '//trim(var_name)//&
                  ' for analysis n.'//trim(str_a)//'.'//nl//&
                   'Choose "velocity", "pressure", "vorticity".')
      end select
     end do
    end if
    vars_str = ''
    ! Double loop to avoid double call to the same variable
    !  n_vars_int = 0
    if ( probe_vel ) vars_str = trim(vars_str)//'     u     v     w' ! ; n_vars_int = n_vars_int + 3  
    if ( probe_p   ) vars_str = trim(vars_str)//'     p'             ! ; n_vars_int = n_vars_int + 1  
    if ( probe_vort) vars_str = trim(vars_str)//'   omx   omy   omz' ! ; n_vars_int = n_vars_int + 3  
     
    ! load the geo components just once just once
    call open_hdf5_file(trim(data_basename)//'_geo.h5', floc)
    !TODO: here get the run id
    call load_components_postpro(comps, points, nelem,  floc, & 
                                 components_names,  all_comp)

    call close_hdf5_file(floc)

    ! Prepare_geometry_postpro
    call prepare_geometry_postpro(comps)

    ! Allocate and point to sol
    allocate(sol(nelem)) ; sol = 0.0_wp
    ip = 0
    do ic = 1 , size(comps)
     do ie = 1 , size(comps(ic)%el)
      ip = ip + 1
      comps(ic)%el(ie)%idou => sol(ip) 
     end do
    end do

    ! Open output .dat file
    fid_out = 21
    write(filename,'(A)') trim(basename)//'_'//trim(an_name)//'.dat'
    open(unit=fid_out,file=trim(filename)) 
      
    call dat_out_probes_header( fid_out , rr_probes , vars_str )

    !time history
    do it =an_start, an_end, an_step

     ! Open the result file ----------------------
     write(filename,'(A,I4.4,A)') trim(data_basename)//'_res_',it,'.h5'
     call open_hdf5_file(trim(filename),floc)

     ! Load u_inf --------------------------------
     call open_hdf5_group(floc,'Parameters',ploc)
     call read_hdf5(u_inf,'u_inf',ploc)
     call read_hdf5(P_inf,'P_inf',ploc)
     call read_hdf5(rho,'rho_inf',ploc)
     call close_hdf5_group(ploc)

     ! Load the references and move the points ---
     call load_refs(floc,refs_R,refs_off)
     call update_points_postpro(comps, points, refs_R, refs_off)
     ! Load the results --------------------------
     call load_res(floc, comps, vort, cp, t)
     sol = vort

     ! Load the wake -----------------------------
     call load_wake_pan(floc, wpoints_pan, wstart, wvort_pan)
   
     call close_hdf5_file(floc)
     
     call prepare_wake_postpro( wpoints_pan , wstart , wvort_pan , wake )

     write(fid_out,'(F12.6)',advance='no') t 

     ! Compute velocity --------------------------
     do ip = 1 , n_probes ! probes

      vel_probe = 0.0_wp ; pres_probe = 0.0_wp ; vort_probe = 0.0_wp
      if ( probe_vel .or. probe_p ) then 
        ! compute velocity
        do ic = 1,size(comps)
         do ie = 1 , size( comps(ic)%el )

          call comps(ic)%el(ie)%compute_vel( rr_probes(:,ip) , u_inf , v )
          vel_probe = vel_probe + v/(4*pi) 
         
         end do
        end do
        ! wake contribution
        do ic = 1 , size(wake%wake_panels,1)
         do ie = 1 , size(wake%wake_panels,2)
               
          call wake%wake_panels(ic,ie)%compute_vel( rr_probes(:,ip) , u_inf , v )
          vel_probe = vel_probe + v/(4*pi) 
         
         end do
        end do

        ! + u_inf
        vel_probe = vel_probe + u_inf
        write(fid_out,'(3F12.6)',advance='no') vel_probe
      end if

      ! compute pressure
      if ( probe_p ) then
        ! Bernoulli equation
        ! rho * dphi/dt + P + 0.5*rho*V^2 = P_infty + 0.5*rho*V_infty^2
        !TODO: add:
        ! - add the unsteady term: -rho*dphi/dt
        pres_probe = P_inf + 0.5_wp*rho*norm2(u_inf)**2 - 0.5_wp*rho*norm2(vel_probe)**2
        write(fid_out,'(F12.6)',advance='no') pres_probe
      end if
      
      ! compute vorticity
      if ( probe_vort ) then
        vort_probe = 2.0_wp
        write(fid_out,'(3F12.6)',advance='no') vort_probe
      end if

     end do  ! probes

     write(fid_out,*) ' '

    end do ! Time history

    close(fid_out)

    deallocate(comps)
    deallocate(rr_probes,sol)


   case('flow_field')

    allocate(vars_name(3)) ; vars_name = ' '
    allocate(vars_n   (3)) ; vars_n = 0

    ! Read variables to save : velocity | pressure | vorticity
    probe_vel = .false. ; probe_p = .false. ; probe_vort = .false.
    n_vars = countoption(sbprms,'Variable')

    if ( n_vars .eq. 0 ) then ! default: velocity | pressure | vorticity
      probe_vel = .true. ; probe_p = .true. ; probe_vort = .true.
    else
     do it = 1 , n_vars
      var_name = getstr(sbprms,'Variable')
      select case(trim(var_name))
       case ( 'velocity' ) ; probe_vel = .true.
       case ( 'pressure' ) ; probe_p   = .true.
       case ( 'vorticity') ; probe_vort= .true.
       case ( 'all') ; probe_vel = .true. ; probe_p   = .true. ; probe_vort= .true.
       case default
       call error('dust_post','','Unknown Variable: '//trim(var_name)//&
                  ' for analysis n.'//trim(str_a)//'.'//nl//&
                   'Choose "velocity", "pressure", "vorticity".')
      end select
     end do
    end if

    ! load the geo components just once just once
    call open_hdf5_file(trim(data_basename)//'_geo.h5', floc)
    !TODO: here get the run id    !todo????
    call load_components_postpro(comps, points, nelem, floc, & 
                                 components_names,  all_comp)

    call close_hdf5_file(floc)

    ! Prepare_geometry_postpro
    call prepare_geometry_postpro(comps)

    ! Allocate and point to sol
    allocate(sol(nelem)) ; sol = 0.0_wp
    ip = 0
    do ic = 1 , size(comps)
     do ie = 1 , size(comps(ic)%el)
      ip = ip + 1
      comps(ic)%el(ie)%idou => sol(ip) 
     end do
    end do

    ! Read box dimensions
    nxyz   = getintarray( sbprms,'Nxyz'  ,3)
    minxyz = getrealarray(sbprms,'Minxyz',3)
    maxxyz = getrealarray(sbprms,'Maxxyz',3)

!   allocate( xbox(nxyz(1)), ybox(nxyz(2)) , zbox(nxyz(3)) ) 
    if ( nxyz(1) .gt. 1 ) then
      allocate( xbox(nxyz(1)) )
      dxbox = ( maxxyz(1) - minxyz(1) ) / dble( nxyz(1) - 1 ) 
      xbox = (/ ( minxyz(1) + dble(i1-1) * dxbox , i1 = 1 , nxyz(1) )/) 
    else
      allocate( xbox(1) )
      xbox(1) = minxyz(1)
    end if
    if ( nxyz(2) .gt. 1 ) then
      allocate( ybox(nxyz(2)) )
      dybox = ( maxxyz(2) - minxyz(2) ) / dble( nxyz(2) - 1 ) 
      ybox = (/ ( minxyz(2) + dble(i1-1) * dybox , i1 = 1 , nxyz(2) )/) 
    else
      allocate( ybox(1) )
      ybox(1) = minxyz(2)
    end if
    if ( nxyz(3) .gt. 1 ) then
      allocate( zbox(nxyz(3)) )
      dzbox = ( maxxyz(3) - minxyz(3) ) / dble( nxyz(3) - 1 ) 
      zbox = (/ ( minxyz(3) + dble(i1-1) * dzbox , i1 = 1 , nxyz(3) )/) 
    else
      allocate( zbox(1) )
      zbox(1) = minxyz(3)
    end if

    i_var = 0
    i_var_v = 0 ; i_var_p = 0 ; i_var_w = 0
    if ( probe_vel ) then
      allocate(box_vel (product(nxyz),3))
      i_var = i_var + 1
      vars_name(i_var) = 'velocity'
      vars_n(i_var) = 3
      i_var_v = 3
    end if
    if ( probe_p   ) then
      allocate(box_p   (product(nxyz)  ))
      i_var = i_var + 1
      vars_name(i_var) = 'pressure'
      vars_n(i_var) = 1
      i_var_p = i_var_v + 1
    end if 
    if ( probe_vort) then
      allocate(box_vort(product(nxyz),3))
      i_var = i_var + 1
      vars_name(i_var) = 'vorticity'
      vars_n(i_var) = 3
      i_var_w = i_var_p + 3
    end if
    allocate(vars(sum(vars_n),product(nxyz))) ; vars = 1.0_wp 

    do it = an_start, an_end, an_step ! Time history

     ! Open the result file ----------------------
     write(filename,'(A,I4.4,A)') trim(data_basename)//'_res_',it,'.h5'
     call open_hdf5_file(trim(filename),floc)

     ! Load u_inf --------------------------------
     call open_hdf5_group(floc,'Parameters',ploc)
     call read_hdf5(u_inf,'u_inf',ploc)
     call read_hdf5(P_inf,'P_inf',ploc)
     call read_hdf5(rho,'rho_inf',ploc)
     call close_hdf5_group(ploc)

     ! Load the references and move the points ---
     call load_refs(floc,refs_R,refs_off)
     call update_points_postpro(comps, points, refs_R, refs_off)
     ! Load the results --------------------------
     call load_res(floc, comps, vort, cp, t)
     sol = vort

     ! Load the wake -----------------------------
     call load_wake_pan(floc, wpoints_pan, wstart, wvort_pan)
   
     call close_hdf5_file(floc)
     
     call prepare_wake_postpro( wpoints_pan , wstart , wvort_pan , wake )

     ! Compute velocity --------------------------
     write(filename,'(A,I4.4,A)') trim(basename)//'_'//trim(an_name)//&
                                                            '_',it,'.vtr'
!    !CHECK
!    fid_out = 21
!    open(unit=fid_out,file=trim(filename)//'_box.dat')
     ip = 0
     ! Loop over the nodes of the box
     do iz = 1 , size(zbox)
      do iy = 1 , size(ybox)
       do ix = 1 , size(xbox)
        ip = ip + 1

        if ( probe_vel .or. probe_p ) then 
          ! compute velocity
          vel_probe = 0.0_wp ; pres_probe = 0.0_wp ; vort_probe = 0.0_wp
          do ic = 1,size(comps)
           do ie = 1 , size( comps(ic)%el )

!           call comps(ic)%el(ie)%compute_vel( rr_probes(:,ip) , u_inf , v )
            call comps(ic)%el(ie)%compute_vel( (/ xbox(ix) , ybox(iy) , zbox(iz) /) , & 
                                                u_inf , v )
            vel_probe = vel_probe + v/(4*pi) 
           
           end do
          end do
          ! wake contribution
          do ic = 1 , size(wake%wake_panels,1)
           do ie = 1 , size(wake%wake_panels,2)
                 
            call wake%wake_panels(ic,ie)%compute_vel( &
                 (/ xbox(ix) , ybox(iy) , zbox(iz) /) , u_inf , v )
            vel_probe = vel_probe + v/(4*pi) 
           
           end do
          end do
  
          ! + u_inf
          vel_probe = vel_probe + u_inf
          
        end if
        if ( probe_vel ) then
!         vars(1:3,ix+(iy-1)*size(xbox)+(iz-1)*size(xbox)*size(ybox)) = vel_probe
          vars(1:3,ip) = vel_probe
        end if

        if ( probe_p ) then
          ! Bernoulli equation
          ! rho * dphi/dt + P + 0.5*rho*V^2 = P_infty + 0.5*rho*V_infty^2
          !TODO: add:
          ! - add the unsteady term: -rho*dphi/dt
          pres_probe = P_inf + 0.5_wp*rho*norm2(u_inf)**2 - 0.5_wp*rho*norm2(vel_probe)**2
          vars(i_var_v+1,ip) = pres_probe 
   !       
        end if

        if ( probe_vort ) then

        end if

       end do
      end do
     end do

     call vtr_write ( filename , xbox , ybox , zbox , &
                      vars_n(1:i_var) , vars_name(1:i_var) , vars ) 

!    !CHECK
!    close(fid_out)

    end do ! Time history

    if (allocated(box_vel )) deallocate(box_vel )
    if (allocated(box_p   )) deallocate(box_p   )
    if (allocated(box_vort)) deallocate(box_vort)
    deallocate(xbox,ybox,zbox)
    deallocate(comps,sol)

    deallocate(vars_name,vars_n,vars)

   case default
    call error('dust_post','','Unknown type of analysis: '//trim(an_type))

  end select


  
  if(allocated(var_names)) deallocate(var_names)
  if(allocated(components_names)) deallocate(components_names)

  sbprms => null()
enddo !analysis

call destroy_hdf5()
call printout(nl//'<<<<<< DUST POSTPROCESSOR end       <<<<<<'//nl)

!----------------------------------------------------------------------
!----------------------------------------------------------------------
contains
!----------------------------------------------------------------------
!----------------------------------------------------------------------

!subroutine load_comp(floc, components_names, elems, points)
! integer(h5loc), intent(in) :: floc 
! character(len=*), allocatable, intent(in) :: components_names(:)
! integer, allocatable, intent(out) :: elems(:,:)
! real(wp), allocatable, intent(out) :: points(:,:)
!
! integer :: nelem, npoints
! integer(h5loc) :: gloc1, gloc2
! integer :: i_comp, n_comp
! character(len=max_char_len) :: cname, cname2
!
! real(wp), allocatable :: points_tmp(:,:), points_read(:,:)
! integer, allocatable ::  elems_tmp(:,:), elems_read(:,:)
!
!  call open_hdf5_group(floc,'Components',gloc1)
!  call read_hdf5(n_comp,'NComponents',gloc1)
!  
!  nelem = 0; npoints = 0;
!
!  do i_comp = 1, n_comp
!    write(cname,'(A,I3.3)') 'Comp',i_comp
!    call open_hdf5_group(gloc1,trim(cname),gloc2)
!
!    call read_hdf5(cname2, 'CompName', gloc2)
!    !read the components contents only if it is in the list
!    if(IsInList(cname2, components_names) .or. all_comp) then
!
!      call read_hdf5_al(elems_read, 'ee', gloc2)
!      call read_hdf5_al(points_read,'rr', gloc2)
!      !increase the connectivity indexes
!      where(elems_read .gt. 0)
!        elems_read = elems_read + npoints
!      end where
!
!
!      allocate(elems_tmp(4,nelem+size(elems_read,2))) 
!      allocate(points_tmp(3,npoints+size(points_read,2)))
!
!      if (allocated(elems)) elems_tmp(:,1:nelem) = elems
!      if (allocated(points)) points_tmp(:,1:npoints) = points
!
!      elems_tmp(:,nelem+1:ubound(elems_tmp,2)) = elems_read
!      points_tmp(:,npoints+1:ubound(points_tmp,2)) = points_read
!
!      call move_alloc(elems_tmp, elems)
!      call move_alloc(points_tmp, points)
!      deallocate(elems_read, points_read)
!
!
!
!      nelem = nelem + size(elems_read,2)
!      npoints = npoints + size(points_read,2)
!
!    endif
!    
!    call close_hdf5_group(gloc2)
!  enddo
!
!end subroutine

!----------------------------------------------------------------------

subroutine load_refs(floc, refs_R, refs_off)
 integer(h5loc), intent(in) :: floc 
 real(wp), allocatable, intent(out) :: refs_R(:,:,:)
 real(wp), allocatable, intent(out) :: refs_off(:,:)

 integer(h5loc) :: gloc1, gloc2
 integer :: nrefs, iref
 character(len=max_char_len) :: rname

  call open_hdf5_group(floc,'References',gloc1)
  call read_hdf5(nrefs,'NReferences',gloc1)

  allocate(refs_R(3,3,0:nrefs-1), refs_off(3,0:nrefs-1))
  do iref = 0,nrefs-1
    write(rname,'(A,I3.3)') 'Ref',iref
    call open_hdf5_group(gloc1,trim(rname),gloc2)
   
    call read_hdf5(refs_R(:,:,iref),'R',gloc2)
    call read_hdf5(refs_off(:,iref),'Offset',gloc2)

    call close_hdf5_group(gloc2)
  enddo

  call close_hdf5_group(gloc1)

end subroutine load_refs

!----------------------------------------------------------------------

subroutine load_res(floc, comps, vort, cp, t)
 integer(h5loc), intent(in) :: floc 
 type(t_geo_component), intent(in) :: comps(:)
 real(wp), allocatable, intent(out) :: vort(:)
 real(wp), allocatable, intent(out) :: cp(:)
 real(wp), intent(out) :: t

 integer :: ncomps, icomp, ie
 integer :: nelems, offset, nelems_comp
 integer(h5loc) :: gloc1, gloc2, gloc3
 character(len=max_char_len) :: cname
 real(wp), allocatable :: vort_read(:), cp_read(:)

  ncomps = size(comps)
  nelems = 0
  do icomp = 1, ncomps
    select type(el=>comps(icomp)%el)
     class default
      nelems = nelems + comps(icomp)%nelems 
     type is(t_actdisk)
      nelems = nelems + size(comps(icomp)%loc_points,2)
    end select
  enddo
  
  call read_hdf5(t,'time',floc)
  allocate(vort(nelems), cp(nelems))
  call open_hdf5_group(floc,'Components',gloc1)

  offset = 0
  do icomp = 1, ncomps
    
    nelems_comp = comps(icomp)%nelems
    write(cname,'(A,I3.3)') 'Comp',comps(icomp)%comp_id
    call open_hdf5_group(gloc1,trim(cname),gloc2)
    call open_hdf5_group(gloc2,'Solution',gloc3)

    !call read_hdf5(vort(offset+1:offset+nelems_comp),'Vort',gloc3)
    !call read_hdf5(cp(offset+1:offset+nelems_comp),'Cp',gloc3)
    call read_hdf5_al(vort_read,'Vort',gloc3)
    call read_hdf5_al(cp_read,'Cp',gloc3)

    call close_hdf5_group(gloc3)
    call close_hdf5_group(gloc2)

    select type(el =>comps(icomp)%el)
     class default
      vort(offset+1:offset+nelems_comp) = vort_read
      cp(offset+1:offset+nelems_comp) = cp_read
      offset = offset + nelems_comp
     type is(t_actdisk)
      do ie = 1,nelems_comp
        vort(offset+1:offset+el(ie)%n_ver) = vort_read(ie)
        cp(offset+1:offset+el(ie)%n_ver) = cp_read(ie)
        offset = offset + el(ie)%n_ver
      enddo
    end select

    deallocate(vort_read, cp_read)

  enddo

  call close_hdf5_group(gloc1)

end subroutine load_res

!----------------------------------------------------------------------

subroutine load_wake_pan(floc, wpoints, wstart, wvort)
 integer(h5loc), intent(in) :: floc 
 real(wp), allocatable, intent(out) :: wpoints(:,:,:)
 integer, allocatable, intent(out) :: wstart(:,:)
 real(wp), allocatable, intent(out) :: wvort(:,:)

 integer(h5loc) :: gloc
  
  call open_hdf5_group(floc,'PanelWake',gloc)
  
  call read_hdf5_al(wpoints,'WakePoints',gloc)
  call read_hdf5_al(wstart,'StartPoints',gloc)
  call read_hdf5_al(wvort,'WakeVort',gloc)

  call close_hdf5_group(gloc)

end subroutine load_wake_pan

!----------------------------------------------------------------------

subroutine load_wake_ring(floc, wpoints, wconn, wcen, wvort)
 integer(h5loc), intent(in) :: floc 
 real(wp), allocatable, intent(out) :: wpoints(:,:,:)
 integer, allocatable, intent(out) :: wconn(:)
 real(wp), allocatable, intent(out) :: wcen(:,:,:)
 real(wp), allocatable, intent(out) :: wvort(:,:)

 integer(h5loc) :: gloc
  
  call open_hdf5_group(floc,'RingWake',gloc)
  
  call read_hdf5_al(wpoints,'WakePoints',gloc)
  call read_hdf5_al(wconn,'Conn_pe',gloc)
  call read_hdf5_al(wcen,'WakeCenters',gloc)
  call read_hdf5_al(wvort,'WakeVort',gloc)

  call close_hdf5_group(gloc)

end subroutine load_wake_ring

!----------------------------------------------------------------------

subroutine load_wake_viz(floc, wpoints, welems, wvort)
 integer(h5loc), intent(in) :: floc 
 real(wp), allocatable, intent(out) :: wpoints(:,:)
 integer, allocatable, intent(out)  :: welems(:,:)
 real(wp), allocatable, intent(out) :: wvort(:)

 integer(h5loc) :: gloc
 logical :: got_dset 
 real(wp), allocatable :: wpoints_read(:,:,:)
 real(wp), allocatable :: wpoints_pan(:,:), wpoints_rin(:,:)
 integer, allocatable  :: wstart(:,:), wconn(:)
 real(wp), allocatable :: wcen(:,:,:)
 real(wp), allocatable :: wvort_read(:,:)
 real(wp), allocatable :: wvort_pan(:), wvort_rin(:)
 integer, allocatable  :: welems_pan(:,:), welems_rin(:,:)
 integer :: nstripes, npoints_row, nrows, ndisks, nelem_w
 integer :: iew, ir, is, ip
 integer :: first_elem, act_disk, next_elem


 !get the panel wake
 got_dset = check_dset_hdf5('PanelWake',floc)
 if(got_dset) then

  call open_hdf5_group(floc,'PanelWake',gloc)
  call read_hdf5_al(wpoints_read,'WakePoints',gloc)
  call read_hdf5_al(wstart,'StartPoints',gloc)
  call read_hdf5_al(wvort_read,'WakeVort',gloc)


  nstripes = size(wvort_read,1); nrows = size(wvort_read,2);
  npoints_row = size(wpoints_read,2)
  nelem_w = nstripes*nrows

  allocate(wpoints_pan(3,npoints_row*(nrows+1)))
  allocate(welems_pan(4,nelem_w))
  allocate(wvort_pan(nelem_w))

  wpoints_pan = reshape(wpoints_read, (/3,npoints_row*(nrows+1)/))
  wvort_pan = reshape(wvort_read, (/nelem_w/))
  iew = 0
  do ir = 1,nrows
    do is = 1,nstripes
      iew = iew+1
      welems_pan(:,iew) = (/wstart(1,is)+npoints_row*(ir-1), &
                            wstart(2,is)+npoints_row*(ir-1), &
                            wstart(2,is)+npoints_row*(ir), &
                            wstart(1,is)+npoints_row*(ir)/)
    enddo
  enddo
 
  deallocate(wpoints_read, wstart, wvort_read)
  call close_hdf5_group(gloc)
 else
   !panel wake not present, allocate stuff at zero size
   allocate(wvort_pan(0), wpoints_pan(3,0), welems_pan(4,0))
 endif

 !get the ring wake
 got_dset = check_dset_hdf5('RingWake',floc)
 if(got_dset) then

  call open_hdf5_group(floc,'RingWake',gloc)
  call read_hdf5_al(wpoints_read,'WakePoints',gloc)
  call read_hdf5_al(wconn,'Conn_pe',gloc)
  call read_hdf5_al(wcen,'WakeCenters',gloc)
  call read_hdf5_al(wvort_read,'WakeVort',gloc)
  
  ndisks = size(wvort_read,1); nrows = size(wvort_read,2)
  npoints_row = size(wpoints_read,2)

  nelem_w = ndisks*nrows

  allocate(wpoints_rin(3,npoints_row*nrows+nelem_w))
  allocate(welems_rin(4,npoints_row*nrows))
  allocate(wvort_rin(npoints_row*nrows))

  wpoints_rin(:,1:npoints_row*nrows) = reshape(wpoints_read, &
                                          (/3,npoints_row*nrows/))
  wpoints_rin(:,npoints_row*nrows+1:size(wpoints_rin,2)) = &
         reshape(wcen, (/3,nelem_w/))

  iew = 0; act_disk = 0
  do ir = 1,nrows
    do ip = 1, npoints_row
      iew = iew+1

      if(ip .eq. 1) then
        first_elem = iew
      else
        if(wconn(ip-1) .ne. wconn(ip)) first_elem = iew
      endif

      if(ip.lt.npoints_row) then
        if(wconn(ip+1) .ne. wconn(ip)) then
          next_elem = first_elem
        else
          next_elem = iew + 1
        endif
      else
        next_elem = first_elem
      endif

      welems_rin(1,iew) = iew
      welems_rin(2,iew) = next_elem
      !welems_rin(3,iew) = npoints_row*nrows+(ir-1)*nelem_w+wconn(ip)
      welems_rin(3,iew) = npoints_row*nrows+(ir-1)*ndisks+wconn(ip)
      welems_rin(4,iew) = 0

      wvort_rin(iew) = wvort_read(wconn(ip),ir)
    enddo
  enddo

  call close_hdf5_group(gloc)
  deallocate(wpoints_read, wconn, wcen, wvort_read) 
 else
   allocate(wvort_rin(0), wpoints_rin(3,0), welems_rin(4,0))
 endif

 !Stitch together the two wakes
 allocate(wpoints(3,size(wpoints_pan,2)+size(wpoints_rin,2)))
 wpoints(:,1:size(wpoints_pan,2)) = wpoints_pan
 wpoints(:,size(wpoints_pan,2)+1:size(wpoints,2)) = wpoints_rin
 deallocate(wpoints_pan, wpoints_rin)

 allocate(welems(4,size(welems_pan,2)+size(welems_rin,2)))
 welems(:,1:size(welems_pan,2)) = welems_pan
 welems(1:3,size(welems_pan,2)+1:size(welems,2)) = welems_rin(1:3,:) + &
                                                   size(wpoints_pan,2)
 welems(4,size(welems_pan,2)+1:size(welems,2)) = 0
 deallocate(welems_pan, welems_rin)


 allocate(wvort(size(wvort_pan)+size(wvort_rin)))
 wvort(1:size(wvort_pan)) = wvort_pan
 wvort(size(wvort_pan)+1:size(wvort)) = wvort_rin
 deallocate(wvort_pan, wvort_rin)

end subroutine load_wake_viz

!----------------------------------------------------------------------

end program dust_post

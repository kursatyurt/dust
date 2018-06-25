module mod_post_probes

use mod_param, only: &
  wp, nl, max_char_len, extended_char_len , pi

use mod_handling, only: &
  error, warning ! , info, printout, dust_time, t_realtime, new_file_unit

use mod_geometry, only: &
  t_geo_component ! , t_geo

use mod_parse, only: &
  t_parse, &
  getstr, getrealarray, &
  countoption

use mod_hdf5_io, only: &
! initialize_hdf5, destroy_hdf5, &
   h5loc, &
!  new_hdf5_file, &
   open_hdf5_file, &
   close_hdf5_file , &
!  new_hdf5_group, &
   open_hdf5_group, &
   close_hdf5_group, &
!  write_hdf5, &
   read_hdf5
!  read_hdf5_al, &
!  check_dset_hdf5

use mod_stringtools, only: &
  LowCase !, isInList, stricmp

use mod_geo_postpro, only: &
  load_components_postpro, update_points_postpro , prepare_geometry_postpro , &
  prepare_wake_postpro  ! expand_actdisk_postpro, 

use mod_aeroel, only: &
  c_elem, c_pot_elem, c_vort_elem, c_impl_elem, c_expl_elem, &
  t_elem_p, t_pot_elem_p, t_vort_elem_p, t_impl_elem_p, t_expl_elem_p

use mod_wake_pan, only: &
  t_wake_panels

use mod_wake_ring, only: &
  t_wake_rings

use mod_actuatordisk, only: &
  t_actdisk

use mod_post_load, only: &
  load_refs, load_res, load_wake_viz , load_wake_pan , load_wake_ring

implicit none

public :: post_probes

private


contains

! ---------------------------------------------------------------------- 

subroutine post_probes( sbprms , basename , data_basename , an_name , ia , &
                      out_frmt , comps , components_names , all_comp , &
                      an_start , an_end , an_step )
type(t_parse), pointer :: sbprms
character(len=*) , intent(in) :: basename
character(len=*) , intent(in) :: data_basename
character(len=*) , intent(in) :: an_name
integer          , intent(in) :: ia
character(len=*) , intent(in) :: out_frmt
type(t_geo_component), allocatable , intent(inout) :: comps(:)
character(len=max_char_len), allocatable , intent(inout) :: components_names(:)
logical , intent(in) :: all_comp
integer , intent(in) :: an_start , an_end , an_step

integer :: nstep
real(wp), allocatable :: probe_vars(:,:,:)
real(wp), allocatable :: time(:)
character(len=max_char_len), allocatable :: probe_var_names(:)
character(len=max_char_len), allocatable :: probe_loc_names(:)
character(len=max_char_len) :: in_type , str_a , filename_in , var_name , vars_str
integer :: n_probes , n_vars ! , n_vars_int
real(wp), allocatable :: rr_probes(:,:)
logical :: probe_vel , probe_p , probe_vort
integer :: fid_out , i_var , nprint
integer :: ie , ip , ic , it , ires
integer(h5loc) :: floc , ploc
character(len=max_char_len) :: filename
real(wp), allocatable :: points(:,:)
integer, allocatable :: elems(:,:)
integer :: nelem 

real(wp) :: u_inf(3)
real(wp) :: P_inf , rho
real(wp) :: vel_probe(3) = 0.0_wp , vort_probe(3) = 0.0_wp 
real(wp) :: v(3) = 0.0_wp , w(3) = 0.0_wp
real(wp), allocatable , target :: sol(:) 
real(wp) :: pres_probe
real(wp) :: t

real(wp), allocatable :: refs_R(:,:,:), refs_off(:,:)
real(wp), allocatable :: vort(:), cp(:), vel(:), press(:)

! wake ------------
integer, allocatable  :: wstart(:,:)
real(wp), allocatable :: wvort(:), wvort_pan(:,:), wvort_rin(:,:)
real(wp), allocatable :: wpoints(:,:), wpoints_pan(:,:,:), wpoints_rin(:,:,:)
!real(wp), allocatable :: wcen(:,:,:)
integer,  allocatable :: wconn(:)
type(t_wake_panels) :: wake_pan
type(t_wake_rings)  :: wake_rin
type(t_elem_p), allocatable :: wake_elems(:)

    write(*,*) nl//' Analysis:',ia,' post_probes() ++++++++++++ '//nl

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
    ! TODO: add Cp
    probe_vel = .false. ; probe_p = .false. ; probe_vort = .false.
    n_vars = countoption(sbprms,'Variable')
    !DEBUG
    write(*,*) ' n_vars : ' , n_vars

    if ( n_vars .eq. 0 ) then ! default: velocity | pressure | vorticity
      probe_vel = .true. ; probe_p = .true. ; probe_vort = .true.
    else
     do i_var = 1 , n_vars
      var_name = getstr(sbprms,'Variable')
      write(*,*) ' trim(var_name) : ' , trim(var_name) ; call LowCase(var_name)
      select case(trim(var_name))
       case ( 'velocity' ) ; probe_vel = .true.
       case ( 'pressure' ) ; probe_p   = .true.
       case ( 'vorticity') ; probe_vort= .true.
       case ( 'cp'       ) 
        write(str_a,*) ia 
        call error('dust_post','','Unknown Variable: '//trim(var_name)//&
                   ' for analysis n.'//trim(str_a)//'.'//nl//&
                    'Choose "velocity", "pressure", "vorticity".')
       case ( 'all') ; probe_vel = .true. ; probe_p   = .true. ; probe_vort= .true.
       case default
        write(str_a,*) ia 
        call error('dust_post','','Unknown Variable: '//trim(var_name)//&
                   ' for analysis n.'//trim(str_a)//'.'//nl//&
                    'Choose "velocity", "pressure", "vorticity".')
      end select
     end do
    end if

    ! Find the number of fields to be plotted ( vec{vel} , p , vec{omega}) 
    nprint = 0
    if(probe_vel)  nprint = nprint+3
    if(probe_p)    nprint = nprint+1
    if(probe_vort) nprint = nprint+3

    ! Write .dat file header
    allocate(probe_var_names(nprint))
    allocate(probe_loc_names(n_probes))
    probe_var_names = ''
    i_var = 1
    if(probe_vel) then
      probe_var_names(i_var)     = 'ux'
      probe_var_names(i_var + 1) = 'uy'
      probe_var_names(i_var + 2) = 'uz'
      i_var = i_var + 3
    endif
    if(probe_p) then
      probe_var_names(i_var) = 'p'
      i_var = i_var + 1
    endif
    if(probe_vort) then
      probe_var_names(i_var)     = 'omx'
      probe_var_names(i_var + 1) = 'omy'
      probe_var_names(i_var + 2) = 'omz'
      i_var = i_var + 3
    endif
    vars_str = ''
    do i_var = 1,size(probe_var_names)
      vars_str = trim(vars_str)//'  '//trim(probe_var_names(i_var))
    enddo

    do ip = 1,n_probes
      write(probe_loc_names(ip),'(A,F10.5,A,F10.5,A,F10.5)') &
           'x=',rr_probes(1,ip), &
           'y=',rr_probes(2,ip), &
           'z=',rr_probes(3,ip)
    enddo

    !Allocate where the solution will be stored
    nstep = (an_end-an_start)/an_step + 1
    allocate(probe_vars(nprint, nstep, n_probes))
    allocate(time(nstep))


    ! load the geo components just once
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
      comps(ic)%el(ie)%mag => sol(ip) 
     end do
    end do

    !time history
    ires = 0
    do it =an_start, an_end, an_step
      ires = ires+1

! quick and dirty copy and paste -------

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
     !sol = vort

     ! Load the wake -----------------------------
     call load_wake_pan(floc, wpoints_pan, wstart, wvort_pan)
     call load_wake_ring(floc, wpoints_rin, wconn, wvort_rin)
   
     call close_hdf5_file(floc)
     
     call prepare_wake_postpro( wpoints_pan, wpoints_rin, wstart, wconn, &
                 wvort_pan,  wvort_rin, wake_pan, wake_rin, wake_elems )

     time(ires) = t

     ! Compute velocity --------------------------
     do ip = 1 , n_probes ! probes

      vel_probe = 0.0_wp ; pres_probe = 0.0_wp ; vort_probe = 0.0_wp
      i_var = 1
      if ( probe_vel .or. probe_p ) then 

        ! compute velocity
        do ic = 1,size(comps)
         do ie = 1 , size( comps(ic)%el )

          call comps(ic)%el(ie)%compute_vel( rr_probes(:,ip) , u_inf , v )
          vel_probe = vel_probe + v/(4*pi) 
         
         end do
        end do

        do ie = 1, size(wake_elems)
          call wake_elems(ie)%p%compute_vel( rr_probes(:,ip) , u_inf , v )
          vel_probe = vel_probe + v/(4*pi) 
        enddo

        !TODO: check ??? is it enough to include all the body and wake elements ???

        ! + u_inf
        vel_probe = vel_probe + u_inf
      end if

      if(probe_vel) then
        probe_vars(i_var:i_var+2, ires, ip) = vel_probe
        i_var = i_var+3
      endif

      ! compute pressure
      if ( probe_p ) then
        ! Bernoulli equation
        ! rho * dphi/dt + P + 0.5*rho*V^2 = P_infty + 0.5*rho*V_infty^2
        !TODO: add:
        ! - add the unsteady term: -rho*dphi/dt
        pres_probe = P_inf + 0.5_wp*rho*norm2(u_inf)**2 - 0.5_wp*rho*norm2(vel_probe)**2

        probe_vars(i_var, ires, ip) = pres_probe
        i_var = i_var+1
      end if
      
      ! compute vorticity
      if ( probe_vort ) then
        vort_probe = 0.0_wp
        !write(fid_out,'(3F12.6)',advance='no') vort_probe
        probe_vars(i_var:i_var+2, ires, ip) = vort_probe
        i_var = i_var+3
      end if

     end do  ! probes



! quick and dirty copy and paste -------

    end do

    do ic = 1 , size(comps)
     do ie = 1 , size(comps(ic)%el)
      ip = ip + 1
      comps(ic)%el(ie)%mag => null()  
     end do
    end do
     
    deallocate(sol) 
    deallocate(probe_vars,time)
    deallocate(probe_var_names,probe_loc_names)
    deallocate(rr_probes)

    deallocate(comps, points)


    write(*,*) nl//' post_probes done.'//nl

end subroutine post_probes

! ---------------------------------------------------------------------- 

end module mod_post_probes

!--------------------------------------------------------------------------!
! The Phantom Smoothed Particle Hydrodynamics code, by Daniel Price et al. !
! Copyright (c) 2007-2023 The Authors (see AUTHORS)                        !
! See LICENCE file for usage and distribution conditions                   !
! http://phantomsph.github.io/                                             !
!--------------------------------------------------------------------------!
module testapr
!
! Unit test for adaptive particle refinement
!
! :References:
!
! :Owner: Rebecca Nealon
!
! :Runtime parameters: None
!
! :Dependencies: apr, apr_region, linklist
!
 use testutils, only:checkval,update_test_scores
 use io,        only:id,master
 implicit none
 public :: test_apr,setup_apr_region_for_test

 private

contains

!--------------------------------------------
!+
!  Various tests of the apr module
!+
!--------------------------------------------
subroutine test_apr(ntests,npass)
 use physcon, only:solarm,kpc
 use units,   only:set_units
 use unifdis,      only:set_unifdis
 use io,           only:id,master,fatal
 use boundary,     only:dxbound,dybound,dzbound,xmin,xmax,ymin,ymax,zmin,zmax
 use part,         only:npart,npartoftype,hfact,xyzh,init_part,massoftype
 use part,         only:isetphase,igas,iphase,vxyzu,fxyzu,apr_level
 use mpidomain,    only:i_belong
 use mpiutils,     only:reduceall_mpi
 use dim,          only:periodic,use_apr
 use apr,          only:apr_centre,update_apr
 integer, intent(inout) :: ntests,npass
 real :: psep,rhozero,time,totmass
 integer :: original_npart,splitted

 if (use_apr) then
    if (id==master) write(*,"(/,a)") '--> TESTING APR MODULE'
 else
    if (id==master) write(*,"(/,a)") '--> SKIPPING APR TEST (REQUIRES -DAPR)'
    return
 endif

 ntests = 1

 ! Set up a uniform box of particles
 call init_part()
 psep = dxbound/20.
 time = 0.
 npartoftype(:) = 0
 npart = 0
 rhozero = 1.0
 totmass = rhozero*dxbound*dybound*dzbound
 call set_unifdis('cubic',id,master,xmin,xmax,ymin,ymax,zmin,zmax,psep,&
                  hfact,npart,xyzh,periodic,mask=i_belong)

 original_npart = npart
 massoftype(1) = totmass/reduceall_mpi('+',npart)
 iphase(1:npart) = isetphase(igas,iactive=.true.)

 ! Now set up an APR zone
 call setup_apr_region_for_test()

 ! after splitting, the total number of particles should have been updated
 splitted = npart

 ! Move the apr zone out of the box and update again to merge
 apr_centre(:) = 20.
 call update_apr(npart,xyzh,vxyzu,fxyzu,apr_level)

 ! Check that the original particle number returns
 if (npart == original_npart) then
   npass = 1
 else
   npass = 0
 endif

 if (id==master) write(*,"(/,a)") '<-- APR TEST COMPLETE'

end subroutine test_apr

!--------------------------------------------
!+
!  Set up an APR region that is used in other tests
!+
!--------------------------------------------
subroutine setup_apr_region_for_test()
 use apr,  only:init_apr,update_apr,apr_max_in,ref_dir
 use apr,  only:apr_type,apr_rad
 use part, only:npart,xyzh,vxyzu,fxyzu,apr_level
 use linklist, only:set_linklist
 !real :: ratesq(nrates)
 integer :: ierr

 if (id==master) write(*,"(/,a)") '--> adding an apr region'

 ! set parameters for the region
  apr_max_in  =   1    ! number of additional refinement levels (3 -> 2x resolution)
  ref_dir     =   1     ! increase (1) or decrease (-1) resolution
  apr_type    =  -1     ! choose this so you get the default option which is
                        ! reserved for the test suite
  apr_rad     =   0.25  ! radius of innermost region


 ! initialise
 call init_apr(apr_level,ierr)
 call update_apr(npart,xyzh,vxyzu,fxyzu,apr_level)

end subroutine setup_apr_region_for_test

end module testapr

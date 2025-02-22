module musica_ccpp_micm

  ! Note: "micm_t" is included in an external pre-built MICM library that the host
  ! model is responsible for linking to during compilation
  use ccpp_kinds,           only: kind_phys
  use musica_ccpp_util,     only: has_error_occurred
  use musica_ccpp_namelist, only: filename_of_micm_configuration
  use musica_micm,          only: micm_t

  implicit none
  private

  public :: micm_register, micm_init, micm_run, micm_final, micm, number_of_rate_parameters

  type(micm_t), pointer  :: micm => null( )
  integer :: number_of_rate_parameters = 0

contains

  !> Registers MICM constituent properties with the CCPP
  subroutine micm_register(solver_type, number_of_grid_cells, constituent_props, &
                           micm_species, errmsg, errcode)
    use ccpp_constituent_prop_mod, only: ccpp_constituent_properties_t
    use musica_ccpp_species,       only: musica_species_t
    use musica_util,               only: error_t
    use iso_c_binding,             only: c_int

    integer(c_int),                                   intent(in)  :: solver_type
    integer(c_int),                                   intent(in)  :: number_of_grid_cells
    type(ccpp_constituent_properties_t), allocatable, intent(out) :: constituent_props(:)
    type(musica_species_t),              allocatable, intent(out) :: micm_species(:)
    character(len=512),                               intent(out) :: errmsg
    integer,                                          intent(out) :: errcode

    ! local variables
    type(error_t)                 :: error
    real(kind=kind_phys)          :: molar_mass
    character(len=:), allocatable :: species_name
    logical                       :: is_advected
    integer                       :: number_of_species
    integer                       :: i, species_index

    if (associated( micm )) then
      deallocate( micm )
      micm => null()
    end if
    micm => micm_t(trim(filename_of_micm_configuration), solver_type, &
                   number_of_grid_cells, error)
    if (has_error_occurred(error, errmsg, errcode)) return

    number_of_species = micm%species_ordering%size()
    allocate(constituent_props(number_of_species), stat=errcode)
    if (errcode /= 0) then
      errmsg = "[MUSICA Error] Failed to allocate memory for constituent properties."
      return
    end if

    allocate(micm_species(number_of_species), stat=errcode)
    if (errcode /= 0) then
      errmsg = "[MUSICA Error] Failed to allocate memory for micm species."
      return
    end if

    do i = 1, number_of_species
    associate( map => micm%species_ordering )
      species_name = map%name(i)
      species_index = map%index(i)

      molar_mass = micm%get_species_property_double(species_name, &
                                                    "molecular weight [kg mol-1]", &
                                                    error)
      if (has_error_occurred(error, errmsg, errcode)) return
      is_advected = micm%get_species_property_bool(species_name, &
                                                   "__is advected", &
                                                   error)
      if (has_error_occurred(error, errmsg, errcode)) return

      call constituent_props(species_index)%instantiate( &
        std_name = species_name, &
        long_name = species_name, &
        units = 'kg kg-1', &
        vertical_dim = 'vertical_layer_dimension', &
        default_value = 0.0_kind_phys, &
        min_value = 0.0_kind_phys, &
        molar_mass = molar_mass, &
        advected = is_advected, &
        errcode = errcode, &
        errmsg = errmsg)
      if (errcode /= 0) return

      ! Species are ordered to match the sequence of the MICM state array
      micm_species(species_index) = musica_species_t( &
        name = species_name, &
        unit = 'kg kg-1', &
        molar_mass = molar_mass, &
        index_musica_species = species_index )
    end associate ! map
    end do
    number_of_rate_parameters = micm%user_defined_reaction_rates%size()

  end subroutine micm_register

  !> Initializes MICM
  subroutine micm_init(errmsg, errcode)
    character(len=512), intent(out) :: errmsg
    integer,            intent(out) :: errcode

    errmsg = ''
    errcode = 0

  end subroutine micm_init

  !> Solves chemistry at the current time step
  subroutine micm_run(time_step, temperature, pressure, dry_air_density, &
                      user_defined_rate_parameters, constituents, errmsg, errcode)
    use musica_micm,   only: solver_stats_t
    use musica_util,   only: string_t, error_t
    use iso_c_binding, only: c_double, c_loc

    real(kind_phys),         intent(in)    :: time_step            ! s
    real(kind_phys), target, intent(in)    :: temperature(:,:)     ! K
    real(kind_phys), target, intent(in)    :: pressure(:,:)        ! Pa
    real(kind_phys), target, intent(in)    :: dry_air_density(:,:) ! kg m-3
    real(kind_phys), target, intent(in)    :: user_defined_rate_parameters(:,:,:) ! various units
    real(kind_phys), target, intent(inout) :: constituents(:,:,:)  ! mol m-3
    character(len=512),      intent(out)   :: errmsg
    integer,                 intent(out)   :: errcode

    ! local variables
    type(string_t)       :: solver_state
    type(solver_stats_t) :: solver_stats
    type(error_t)        :: error

    call micm%solve(real(time_step, kind=c_double),      &
                    c_loc(temperature),                  &
                    c_loc(pressure),                     &
                    c_loc(dry_air_density),              &
                    c_loc(constituents),                 &
                    c_loc(user_defined_rate_parameters), &
                    solver_state,                        &
                    solver_stats,                        &
                    error)
    if (has_error_occurred(error, errmsg, errcode)) return

  end subroutine micm_run

  !> Finalizes MICM
  subroutine micm_final(errmsg, errcode)
    character(len=512), intent(out) :: errmsg
    integer,            intent(out) :: errcode

    errmsg = ''
    errcode = 0

    if (associated( micm )) then
      deallocate( micm )
      micm => null()
    end if

  end subroutine micm_final

end module musica_ccpp_micm

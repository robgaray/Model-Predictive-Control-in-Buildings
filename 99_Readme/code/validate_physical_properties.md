# validate_physical_properties.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/validate_physical_properties.R`

## Function

This function validates the physical properties loaded from 03_Physical_properties.csv. It checks that Cp_air and dens_air exist and are positive (error otherwise), and warns if their values differ from the reference values held in Validation_03_Physical_properties.csv. The reference values are read from that file rather than written here, so the standard properties of air are stated once, where the rest of the configuration is.

## Called by

- [load_03_physical_properties.R](load_03_physical_properties.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- physical_properties : Named list. Physical properties loaded from 03_Physical_properties.csv via load_03_physical_properties.R. Expected entries: Cp_air   - Specific heat of air (kJ/kg·K) dens_air - Density of air (kg/m3)
- reference_values    : Named list. Reference values loaded from Validation_03_Physical_properties.csv by load_03_physical_properties.R. Expected entries: Cp_air_ref, dens_air_ref.

## Output data

- Invisibly returns TRUE if all checks pass.
- Raises an error (stop) if any required parameter or reference value is missing, or if a parameter is non-positive. Issues a warning if values differ from their reference values.

## Other notes from the file header

### Code outline

1. Validate Cp_air
2. Validate dens_air

### Usage instructions

```r
validate_physical_properties(physical_properties, reference_values)
```

### Exceptions and special cases

- A reference value missing from Validation_03_Physical_properties.csv stops execution: the comparison this function exists for could not be made, and silently skipping it would hide that the file is incomplete.
- The comparison carries no tolerance. A configured value that differs from its reference in any digit raises a warning, and the simulation continues with the configured value.

## Diagram

![Block diagram of validate_physical_properties.R](validate_physical_properties.jpg)

Also available as [validate_physical_properties.svg](validate_physical_properties.svg).

---

[Back to the code structure index](../Code_Structure.md)

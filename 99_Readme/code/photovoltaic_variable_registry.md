# photovoltaic_variable_registry.R

**Function** &nbsp;·&nbsp; `30_Simulation/05_Models/02_Photovoltaic/03_Functions/photovoltaic_variable_registry.R`

## Function

Gives the path of the variable registry of the type Photovoltaic, Simulation_Variables_Photovoltaic.txt, the one place where the columns of the table of a photovoltaic installation are declared. It is the operation variable_registry of the contract of the type Photovoltaic (see model_type_contract()).

## Called by

- [photovoltaic_model_contract.R](photovoltaic_model_contract.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- paths : List. The paths of the simulator. The variable registry of the photovoltaic installation is the file paths$photovoltaic_variables_file.

## Output data

- Character scalar. The path of the variable registry.

## Other notes from the file header

### Code outline

1. Take the path from the paths of the simulator

### Usage instructions

```r
registry_path <- photovoltaic_variable_registry(paths)
```

## Diagram

![Block diagram of photovoltaic_variable_registry.R](photovoltaic_variable_registry.jpg)

Also available as [photovoltaic_variable_registry.svg](photovoltaic_variable_registry.svg).

---

[Back to the code structure index](../Code_Structure.md)

# --------------------------------------------------------------------------------------
# Serial connection and stepper motor initialization
# --------------------------------------------------------------------------------------

mutable struct StepperSystem{N} 
    con
    pos::MVector{N,Float64}
    id::MVector{N,String}
    step2coord::MVector{N,Any}
    coord2step::MVector{N,Any}
    depend::MVector{N,Any}
end


"""
    stepper_open(dof::Int; port=nothing, baud=9600)

## Description 
Function to open a generic connection and returns a StepperSystem type to control a system of stepper motors
## Arguments
- dof: degrees of freedom
- port: port path. If nothing it'll get the first port of SerialPort.list_serialports
- baud: baud rate (default = 9600)
- testnocon: true for testing purposes. Makes dev.con equals missing
## Observations
The output is a StepperSystem type including the following elements with fixed size (dof):
- con: port connection
- pos: position 
- id: stepper motors IDs
- step2coord: array of functions to convert steps into coordinates
- coord2step: array of functions to convert coordinates into steps
- depend: attribute with the dependecies. To be used with the conversion functions. Allows dependent systems.
Except from con, all the other attributes must be configured (see StepperControl.stepper_config)
"""
function stepper_open(dof::Int; port=nothing, baud=9600, testnocon=false)

    if testnocon
        con = missing
    else
        if isnothing(port)
            port = list_serialports()[1]
        end
        con = SerialPort(port, baud)
    end

    pos = repeat([0.0], dof)
    id = "m" .* string.(1:dof)
    f(x) = float(x) 
    g(x) = Int(round(x))

    dev = StepperSystem{dof}(con, pos, id, repeat([f], dof), repeat([g], dof), 1:dof)

    return dev
end

"""
    linear_step2coord(; spr::Int, r=1.0)

## Description
Linear function to find coordinates from a number of steps
## Arguments
- spr: steps per revolution
- r: bell crank radius. The unit can be used to express angular displacements, in radians.
## Example
```jldoctest
julia> x = linear_step2coord(spr=2048);

julia> x(512)
1.5707963267948966

julia> x(512)*180/π
90.0
```
"""
function linear_step2coord(;spr::Int, r=1.0)
    
    function f(steps::Real) 
        steps = Int(round(steps))
        r*2π*steps/spr
    end
    
    return f
end

"""
    linear_coord2step(; spr::Int, r=1.0)

## Description
Linear function to find steps from a displacement
## Arguments
- spr: steps per revolution
- r: bell crank radius. The unit can be used to express angular displacements, in radians.
## Example
```jldoctest
julia> x = linear_coord2step(spr=2048);

julia> x(π/2)
512
```
"""
function linear_coord2step(;spr::Int, r=1.0) 
    g(coord::Real) = Int(round(coord*spr/(r*2π)))
    return g
end


"""
    stepper_config!(dev::StepperSystem; motorID::AbstractVector=dev.id, step2coord::AbstractVector=dev.step2coord, coord2step::AbstractVector=dev.coord2step, depend::AbstractVector=dev.depend)
    
## Description
Configure stepper system.
## Arguments
- dev: element of StepperSystem type
- motorID: array with motor IDs
- step2coord: function to convert steps into coordinates
- coord2step: function to convert coordinates into steps
- 
## Examples
```jldoctest
julia> r = stepper_open(2);

julia> r.id 
2-element MArray{Tuple{2},String,1,2} with indices SOneTo(2):
 "m1"
 "m2"

julia> r.step2coord[1](10)
10
julia> r.coord2step[1](10)
10

julia> f = linear_step2coord(spr=2048, r=2);

julia> g = linear_coord2step(spr=2048, r=2);

julia> stepper_config!(r, motorID=["x","y"], step2coord=[f], coord2step=[g]);

julia> r.id
2-element MArray{Tuple{2},String,1,2} with indices SOneTo(2):
 "x"
 "y"

 julia> r.step2coord[1](10)
 0.06135923151542565
 julia> r.step2coord[1](2048)/(2π)
 2.0

 julia> r.coord2step[1](10)
 1630
 julia> r.coord2step[1](4π)
 2048
```
"""
function stepper_config!(dev::StepperSystem; motorID::AbstractVector = dev.id, 
                        step2coord::AbstractVector = dev.step2coord, coord2step::AbstractVector = dev.coord2step,
                        depend::AbstractVector = dev.depend)

    n = length(dev.id)
    dev.id = motorID

    if length(step2coord) == 1 
        step2coord = repeat(step2coord, n)
    end
    dev.step2coord = step2coord

    if length(coord2step) ==1
        coord2step = repeat(coord2step, n)
    end
    dev.coord2step = coord2step

    dev.depend = depend

end
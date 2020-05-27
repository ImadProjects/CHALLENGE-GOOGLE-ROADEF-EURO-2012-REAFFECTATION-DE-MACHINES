import Pkg
Pkg.add("JuMP")
Pkg.add("Cbc")

using Cbc
using JuMP

include("dataGoogle.jl")
include("checker.jl")
include("run.jl")

#main(instanceFilename, assignmentFilename, verbose)

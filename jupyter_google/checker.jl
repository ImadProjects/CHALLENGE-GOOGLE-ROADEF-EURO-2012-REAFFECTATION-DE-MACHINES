
# Checks if the solution is a solution that can be checked
# * right number of elements
# * values in [1,data.nbMachines]
function checkVector(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    ### Checking that the solution vector is the right one
    if verbose
        println("Checking the size of the vector")
    end

    if size(solution.assignment,1) != data.nbProcess
        println("Vector solution does not have the correct size")
        println("Size = ", size(solution,1), ", nb process = ", data.nbProcess)
        return false
    else
        if verbose
            println("Test passed")
        end
    end

    println("Checking that the values in the solution are machine indices")
    for i in 1:size(solution.assignment,1)
        if solution.assignment[i] > data.nbMachines || solution.assignment[i] < 0
            println("The machine id is wrong for index ", i, " : value =", solution.assignment[i])
            return false
        end
    end

    if verbose
        println("Test passed")
    end

    return true
end



function checkCapacity(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    if verbose
        println("Checking capacity constraint (without transient)")
    end

    # create a vector with 0 consumption for each machine * resource
    resourceConsumption = zeros(data.nbMachines, data.nbResources)

    ok = true
    for r in 1:data.nbResources # for each resource

        # computing the resource consumption of the processes on each machine
        for p in 1:data.nbProcess   # for each process
            # add its resource consumption for the machine to which it is assigned
            resourceConsumption[solution.assignment[p],r] += data.processReq[p,r]
        end

        # checking hard resource consumption for each machine
        for m in 1:data.nbMachines
            if resourceConsumption[m,r] > data.hardCapacities[m,r]
                println("Capacity violation for machine ", m, " and resource ", r)
                println(resourceConsumption[m,r], " > ", data.hardCapacities[m,r])
                ok = false
            end
        end
    end

    if verbose && ok
        println("Test passed")
    end

    if verbose
        println("Checking capacity constraint (with transient)")
    end
    for r in 1:data.nbResources # for each resource
        if data.transientStatus[r]==1    # if it is transient
            # compute the resource consumption (including processes that were originally assigned to the machine )
            for p in 1:data.nbProcess
                if solution.assignment[p] != data.initialAssignment[p] # if the process has moved
                    resourceConsumption[data.initialAssignment[p],r] += data.processReq[p,r] # add its resource consumption
                end
            end

            # checking hard resource consumption for each machine (including transient processes)
            for m in 1:data.nbMachines
                if resourceConsumption[m,r] > data.hardCapacities[m,r]
                    println("When transient resources considered, capacity violation for machine ", m, " and resource ", r)
                    println(resourceConsumption[m,r], " > ", data.hardCapacities[m,r])
                    ok = false
                end
            end
        end
    end

    if verbose && ok
        println("Test passed")
    end

    return ok
end


function checkDisjunctions(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)

    if verbose
        println("Checking disjunctions between processes of the same service")
    end

    ok = true
    for i in 1:data.nbProcess-1, j in i+1:data.nbProcess # for each process j ≠ i
        # if i and j are in the same service and on the same machine there is a problem
        if data.servicesProcess[i] == data.servicesProcess[j]  && solution.assignment[i] == solution.assignment[j]
            println("Disjunction constraint violation between processes ", i, " and ", j)
            println("Both belong to service",  data.servicesProcess[i], " and are assigned to machine ", solution.assignment[i])
            ok = false
        end
    end

    if verbose && ok
        println("Test passed")
    end

    return ok
end


function checkSpread(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    if verbose
        println("Checking spread constraints ")
    end
    ok = true

    for s in 1:data.nbServices # for each service
        if data.spreadMin[s] != 0 # if it has a spread min

            locationsWithService = zeros(data.nbLocations)  # table used to know which locations have service s
            for p in 1:data.nbProcess   # for each process
                locationsWithService[data.locations[solution.assignment[p]]] = 1    # note that its current location has its service
            end
            nbLocationsWithService = sum(locationsWithService)  # number of locations with this service

            if nbLocationsWithService < data.spreadMin[s]   # should be larger than the spread
                println("Spread constraint violated for service ", s)
                println("Present in ", nbLocationsWithService, " locations < ", data.spreadMin[s])
                ok = false
            end
        end
    end

    if verbose && ok
        println("Test passed")
    end

    return ok
end


function checkDependencies(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    println("Checking dependency constraints")
    ok = true

    # table indicating for each neighborhood if it currently has the service
    servicesInNeighborhood = zeros(data.nbServices,data.nbNeighborhoods)

    for p in 1:data.nbProcess
        servicesInNeighborhood[data.servicesProcess[p],data.neighborhoods[solution.assignment[p]]] = 1
    end

    for s in 1:data.nbServices, n in 1:data.nbNeighborhoods, t in data.dependences[s]
        # there cannot be s and not t
        if servicesInNeighborhood[s,n] == 1 && servicesInNeighborhood[t,n] == 0
            println("Dependency constraint violation")
            println("Service ", s, " is in neighbordhood ", n, " while service ", t, " is not")
            ok = false
        end
    end

    if verbose && ok
        println("Test passed")
    end

    return ok
end


function computeLoadCost(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    val = 0

    # resource consumption for each machine and each resource
    resourceConsumption = zeros(data.nbMachines, data.nbResources)
    for r in 1:data.nbResources,  p in 1:data.nbProcess
            resourceConsumption[solution.assignment[p],r] += data.processReq[p,r]
    end

    # compute the load cost by summing the cost over machines and resources
    for m in 1:data.nbMachines, r in 1:data.nbResources
        # the cost is accounted only if is larger than 0
        val += data.weightLoadCost[r] * max(0, resourceConsumption[m,r] - data.softCapacities[m,r])
    end

    return val
end

function computeBalanceCost(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    totalBalanceCost = 0

    # for each balance cost data
    for b in data.balanceCostDataList
        # table that will contain the remaining capacity for resource r1 on each machine
        slack_r1 = data.hardCapacities[:,b.resource1]
        # table that will contain the remaining capacity for resource r2 on each machine
        slack_r2 = data.hardCapacities[:,b.resource2]

        for p in 1:data.nbProcess   # for each process, remove its resource requirement from the remaining capacity
            slack_r1[solution.assignment[p]] -= data.processReq[p,b.resource1]
            slack_r2[solution.assignment[p]] -= data.processReq[p,b.resource2]
        end

        localBalanceCost = 0    # balance cost for the current value of b
        for m in 1:data.nbMachines  # sum over all machines of the balance costs
            localBalanceCost += max(0, b.target * slack_r1[m] - slack_r2[m])
        end

        totalBalanceCost += b.weight*localBalanceCost
    end

    return totalBalanceCost
end






function computeProcessMoveCost(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    val = 0
    for p in 1:data.nbProcess   # count the number of processses that are not in the same machine after optimizing
        if data.initialAssignment[p] != solution.assignment[p]
            val += data.processMoveCost[p]
        end
    end

    return val
end


function computeMachineMoveCost(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    val = 0
    for p in 1:data.nbProcess
        val += data.machineMoveCosts[data.initialAssignment[p],solution.assignment[p]]
    end

    return val
end

function computeServiceMoveCost(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)
    nbMovesInService = zeros(data.nbServices)   # number of processes that moved inside each service

    for p in 1:data.nbServices  # for each process
        if data.initialAssignment[p] != solution.assignment[p]  # if it moved
            nbMovesInService[data.servicesProcess[p]] += 1  # increase the corresponding service counter
        end
    end

    return maximum(nbMovesInService)    # return the maximum among all services
end




function checkAndComputeCost(data::DataGoogle, solution::SolutionGoogle, verbose::Bool)

    ### Printing the arguments
    if verbose
        println("Checking the solution ")
        print("Solution received is ")
        println(solution.assignment)
        println("Cost : ", solution.cost)
    end


    if ! checkVector(data,solution,verbose)
        println("Cannot check the solution ")
        return
    end

    ok = true

    ok = checkCapacity(data,solution,verbose) && ok
    ok = checkDisjunctions(data, solution, verbose) && ok
    ok = checkSpread(data, solution, verbose) && ok
    ok = checkDependencies(data, solution, verbose) && ok

    if ok
        println("All tests passed: solution feasible ")
    end

    loadCost        = computeLoadCost(data, solution, verbose)
    println("Load cost = ", loadCost)
    balanceCost     = computeBalanceCost(data, solution, verbose)
    println("Balance cost = ", balanceCost)
    processMoveCost = computeProcessMoveCost(data, solution, verbose)
    println("Process move cost = ", processMoveCost)
    machineMoveCost = computeMachineMoveCost(data, solution, verbose)
    println("Machine move cost = ", machineMoveCost)
    serviceMoveCost = computeServiceMoveCost(data, solution, verbose)
    println("Service move cost = ", serviceMoveCost)

    totalCost = loadCost + balanceCost + data.processMoveWeight * processMoveCost + data.serviceMoveWeight * serviceMoveCost + data.machineMoveWeight * machineMoveCost

    println("Objective function = ", totalCost)

    println("Objective recorded in the solution ", solution.cost)

    if totalCost != solution.cost
        println("The two costs do not match")
    end

end

############################
### google challenge    ####
### Author F. Clautiaux ####
############################


using DelimitedFiles


# data structure for data used to compute the balance cost
struct BalanceData
    resource1::Int64        # first resource
    resource2::Int64        # second resource
    target::Int64           # target aimed for the recource consumption
    weight::Int64           # weight of the balance cost
end


# data struture for an instance of Google challenge problem
struct DataGoogle
    nbResources::Int64               # number of resources in the instance
    transientStatus::Array{Int64}    # table indicating if each resource is transient (O/1)
    weightLoadCost::Array{Int64}     # table indicating the weight of load cost for each resource

    nbMachines::Int64                # number of machines
    neighborhoods::Array{Int64}      # table indicating the neighborhood of each machine
    nbNeighborhoods::Int64           # total number of neighbordhoods
    locations::Array{Int64}          # table indicating the location of each machine
    nbLocations::Int64               # total number of locations
    softCapacities::Array{Int64,2}   # softcapacities[m,r] indicates the soft cap of machine m for resource r
    hardCapacities::Array{Int64,2}   # hardcapacities[m,r] indicates the hard cap of machine m for resource r
    machineMoveCosts::Array{Int64,2} # machineMoveCosts[m1,m2] indicates the cost for moving from m1 to m2

    nbServices::Int64                # number of services
    spreadMin::Array{Int64}          # for each service, its spread min
    dependences::Array{Array{Int64}} # for each service, a list of dependences (service numbers)

    nbProcess::Int64                 # number of processes
    servicesProcess::Array{Int64}    # for each process  its service
    processReq::Array{Int64,2}       # processReq[p,r] indicates the consumption of resource r by p
    processMoveCost::Array{Int64}    # cost of moving each process p

    nbBalanceCostData::Int64               # number of balance constraints
    balanceCostDataList::Array{BalanceData} # one for each balance target
    processMoveWeight::Int64        # weight for the process move cost
    serviceMoveWeight::Int64        # weight for the service move cost
    machineMoveWeight::Int64        # weight for the machine move cost

    initialAssignment # for each process, id of the machine in the initial solution
end

struct SolutionGoogle
    assignment::Array{Int64}
    cost::Int64
end


function printData(data::DataGoogle)
    println("### Resources part ###")
    println("nb resources = ", data.nbResources)
    println("transient status = ", data.transientStatus)
    println("weight of load cost = ", data.weightLoadCost)

    println("### Machine part ###")
    println("nbMachines = ", data.nbMachines)
    println("Neighborhoods = ", data.neighborhoods)
    println("Locations = ", data.locations)
    println("Hard cap = ", data.hardCapacities)
    println("Soft cap = ", data.softCapacities)
    println("Machine move costs = ", data.machineMoveCosts)

    println("### Service part ###")
    println("Nb services = ", data.nbServices)
    println("Spread min = ", data.spreadMin)
    println("Dependences = ", data.dependences)

    println("### Process part ###")
    println("Nb process = ", data.nbProcess)
    println("Process Services = ", data.servicesProcess)
    println("Proces requirement = ", data.processReq)
    println("Proces move cost = ", data.processMoveCost)

    println("###Weight part ###")
    println("Nb balance constraints = ", data.nbBalanceCostData)
    println("Balance constraints = ", data.balanceCostDataList)
    println("Process move weight : ", data.processMoveWeight)
    println("Service move weight : ", data.serviceMoveWeight)
    println("Machine move weight : ", data.machineMoveWeight)

    println("###Assignment part ###")
    println("Initial assignment : ", data.initialAssignment)
end



function parserGoogle(datafilename::String, assignmentFileName::String, verbose)
    datafile = open(datafilename)
    data = readdlm(datafile)
    close(datafile)

    ### RESOURCES ###
    nbResources = data[1,1]

    transientStatus = data[2:nbResources+1,1]
    weightLoadCost = data[2:nbResources+1,2]

    offset = nbResources + 2 # offset is used to record the current line number in the file

    ### MACHINES ###
    nbMachines = data[offset,1]

    neighborhoods = data[offset+1:offset+nbMachines,1]

    for i in 1:size(neighborhoods,1)
        neighborhoods[i] += 1
    end

    locations = data[offset+1:offset+nbMachines,2]
    for i in 1:size(locations,1)
        locations[i] += 1
    end

     hardcapacities = data[offset+1:offset+nbMachines,3:2+nbResources]
     softcapacities = data[offset+1:offset+nbMachines,3+nbResources:2+2*nbResources]

    machineMoveCosts = data[offset+1:offset+nbMachines,3+2*nbResources:2+2*nbResources+nbMachines]
    offset += nbMachines+1

    ### SERVICES ###
    nbServices = data[offset,1]

    spreadMin = data[offset+1:offset+nbServices,1]

    dependences = [[] for s=1:nbServices]
    for s in 1:nbServices
        nbDep = data[offset+s,2]
        if nbDep != 0
            dependences[s] = data[offset+s,3:2+nbDep]
            for i in 1:nbDep
                dependences[s][i] += 1
            end
        end
    end

    offset += nbServices + 1

    ### PROCESSES ###
    nbProcess = data[offset,1]

    servicesProcess = data[offset+1:offset+nbProcess,1]
    for i in 1:size(servicesProcess,1)
        servicesProcess[i] += 1
    end

    processRequirement = data[offset+1:offset+nbProcess,2:1+nbResources]
    processMoveCost = data[offset+1:offset+nbProcess,2+nbResources]

    offset += nbProcess + 1

    ### BALANCE ###
    nbBalanceCostData = data[offset,1]

    if(nbBalanceCostData > 1)
        println("Only 0 or 1 balance constraint in the files")
        return
    end

    if(nbBalanceCostData == 0)
        balanceConstraints = []
        balanceCostWeight = []
        balanceDataList = []
    else
        balanceConstraints = data[offset+1:offset+nbBalanceCostData,1:3]
        balanceConstraints[1]+=1
        balanceConstraints[2]+=1
        balanceCostWeight = [data[offset+2,1]]
        balanceDataList = [BalanceData(balanceConstraints[1],balanceConstraints[2],balanceConstraints[3],balanceCostWeight[1])]
    end

    offset += 2*nbBalanceCostData+1

    ### MOVE WEIGHTS
    processMoveWeight = data[offset,1]
    serviceMoveWeight = data[offset,2]
    machineMoveWeight = data[offset,3]

    assignmentfile = open(assignmentFileName)
    rawAssignment = readdlm(assignmentfile)
    close(assignmentfile)

    assignment = Array{Int64}(undef,nbProcess)
    for i in 1:nbProcess
        assignment[i] = rawAssignment[i] + 1
    end

    return DataGoogle(nbResources, transientStatus, weightLoadCost,
                      nbMachines, neighborhoods, size(neighborhoods,1), locations, size(locations,1),
                      softcapacities,hardcapacities, machineMoveCosts,
                      nbServices, spreadMin, dependences,
                      nbProcess, servicesProcess,processRequirement, processMoveCost,
                      nbBalanceCostData,
                      balanceDataList,
                      processMoveWeight, serviceMoveWeight, machineMoveWeight,
                      assignment)
end

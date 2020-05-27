############################
### google challenge    ####
### Author F. Clautiaux ####
############################

# Notes
# Julia uses indices from 1 to size while google data are indexed from 0 to size-1





function main(instanceFilename, assignmentFilename, verbose)

    #verbose = false # true for debug

    println("Received instance files ", instanceFilename, " and ", assignmentFilename)

    # reading the data
    data = parserGoogle(instanceFilename, assignmentFilename, verbose)

    if verbose
        printData(data)
    end

    # solve the problem
    solution = solveGoogle(data,verbose)


    if verbose # print the solution
        println("Solution of cost ", solution.cost)
        for i in 1:data.nbProcess
            print(solution.assignment[i], " ") # here the solution is written with our convention 1..n
        end
        println()
    end

    # test if the solution is feasible and compute its cost
    checkAndComputeCost(data, solution, true) # check if the solution is feasible
end

import os, csv, time, sys, collections

sys.setrecursionlimit(5000)

dirname = os.path.dirname(__file__)

class DecisionPoint:
    """ This includes normal decision points, origins and destinations of the network """

    def __init__(self, id, x, y, isOrigin, isDestination):
        self.id = id
        self.x = x
        self.y = y
        self.isOrigin = isOrigin
        self.isDestination = isDestination
        self.reachableNodes = []


class Paths:
    " All possible paths "

    def __init__(self, startId, endId):
        self.startId = startId
        self.endId = endId
        self.paths = []

    def addPath(self, path):
        self.paths.append(path)

def getPathsByStartEnd(all_paths, startId, endId):
    for x in all_paths:
        if x.startId == startId and x.endId == endId:
            return x
    return None

def analyseList(list, startId:int, endId: int):
    lengths = []
    for x in list:
        lengths.append(len(x))
    counter=collections.Counter(lengths)
    print("-- " + scenarioName + " --- frequency of list lengths from " + str(startId) + " to " + str(endId) + ":")
    print(dict(counter))
    return [*counter.keys()][0] if len([*counter.keys()]) > 0 else None

def getDecisionPointById(decisionPoints, id:int):
    for dp in decisionPoints:
        if (dp.id == id):
            return dp
    return None

def addConnection(decisionPoints, id1:int, id2:int):
    dp1 = getDecisionPointById(decisionPoints, id1)
    dp2 = getDecisionPointById(decisionPoints, id2)
    if (dp1 is None or dp2 is None):
        return
    dp1.reachableNodes.append(dp2.id)
    dp2.reachableNodes.append(dp1.id)

def getAllPossiblePaths(decisionPoints, startingNodes, startPointId: int, endPointId: int, paths):
    p: Paths = getPathsByStartEnd(paths, startPointId, endPointId)
    if (len(p.paths) > 0):
        startingNodes = list(filter(lambda elem: len(elem) <= len(p.paths[0]) + 1, startingNodes))
    newFromNodes = startingNodes[:]
    for node in startingNodes:
        for reachable in getDecisionPointById(decisionPoints, node[-1]).reachableNodes:
            updatedRoute = node[:]
            updatedRoute.append(reachable)
            if reachable in node:
                # walking a circle - do not include that one
                pass
            elif reachable == endPointId:
                # reached the destination => save it as a valid route
                p.addPath(updatedRoute)
            else:
                # destination is not reached yet => keep on searching
                newFromNodes.append(updatedRoute)
        
        if node[-1] != endPointId:
            newFromNodes.remove(node)
    if len(list(filter(lambda number: number[-1] != endPointId, newFromNodes))) > 0:
        getAllPossiblePaths(decisionPoints, newFromNodes, startPointId, endPointId, paths)

# contains (a) the name of the environment = folder name and (b) whether paths from destination to start shall be computed
scenarios = [
    ['env1', False],
    ['env2', False],
    ['env3', False],
    ['airport', False],
    ['airport_dus', False],
    ['hospital', True],
]

for scenario in scenarios:
    start = time.time()

    scenarioName = scenario[0]
    computeReversePaths = scenario[1]

    decisionPointsFile = open(os.path.join(dirname, scenarioName + "/decision_points.csv"), "r")
    originsDestinationsFile = open(os.path.join(dirname, scenarioName +  "/origins_destinations.csv"), "r")
    connectionsFile = open(os.path.join(dirname, scenarioName + "/connections.csv"), "r")

    pathsFile = os.path.join(dirname, scenarioName + "/paths.csv")

    #print("File size: " + str(File(pathsFile).st_size))
    if os.path.getsize(pathsFile) > 10:
        print("Path file of " + scenarioName + "-scenario is not empty --> operations are terminated.")
        continue


    decisionPoints = []

    paths = []


    reader = csv.reader(decisionPointsFile, delimiter=";")
    for line in reader:
        decisionPoints.append(DecisionPoint(int(line[0]), int(line[1]), int(line[2]), False, False));

    reader = csv.reader(originsDestinationsFile, delimiter=";")
    for line in reader:
        isDestination = line[3] == 'true'
        decisionPoints.append(DecisionPoint(int(line[0]), int(line[1]), int(line[2]), not isDestination, isDestination));

    reader = csv.reader(connectionsFile, delimiter=";")

    nb_connections = 0
    nb_allpaths = 0
    nb_takenpaths = 0


    for line in reader:
        addConnection(decisionPoints, int(line[0]), int(line[1]));
        nb_connections += 1
    
    for sPoint in filter(lambda decisionPoint: decisionPoint.isOrigin == True, decisionPoints):
        for dPoint in filter(lambda decisionPoint: decisionPoint.isDestination == True, decisionPoints):
            paths.append(Paths(sPoint.id, dPoint.id))
            getAllPossiblePaths(decisionPoints, [[sPoint.id]], sPoint.id, dPoint.id, paths)
            if computeReversePaths:
                paths.append(Paths(dPoint.id, sPoint.id))
                getAllPossiblePaths(decisionPoints, [[dPoint.id]], dPoint.id, sPoint.id, paths)
        

    print("--- NEW CALCULATION --- " + scenarioName + " ---")

    with open(pathsFile, 'w') as file:
        for x in paths:
            min = analyseList(x.paths, x.startId, x.endId)
            if min is not None:
                outputline = str(x.startId) + ";" + str(x.endId) + ";"
                for y in list(filter(lambda path: len(path) <= min + 4, x.paths)):
                    outputline += ','.join(map(str, y)) + ";"
                file.writelines(outputline[0:-1] + "\n")
                print(str(len(x.paths)) + " possible paths from " + str(x.startId) + " to " + str(x.endId))
                print(str(nb_takenpaths) + " path out of " + str(nb_allpaths) + " taken -- min-length: " + str(min + 4))
                nb_allpaths += len(x.paths)
                nb_takenpaths += len(list(filter(lambda path: len(path) <= min + 4, x.paths)))
            else:
                print("No connection found between " + str(x.startId) + " and " + str(x.endId))
    
    print("Execution time in seconds: " + str(time.time()-start))
    print("The " + scenarioName + " scenario has " + str(len(decisionPoints)) + " decision points.")
    print("The " + scenarioName + " scenario has " + str(nb_connections) + " connections.")

    performanceFile = os.path.join(dirname, "performance.csv")

    with open(performanceFile, 'a') as file:
        #file.writelines("Number Decision Points;Number connections;Number origins;Number destinations;Number all all paths;Number exported paths;Time in seconds\n")
        file.writelines(str(len(decisionPoints)) + ";" + str(nb_connections) + ";" + str(len(list(filter(lambda elem: elem.isOrigin, decisionPoints)))) + ";" + str(len(list(filter(lambda elem: elem.isDestination, decisionPoints)))) +  ";" + str(nb_allpaths) + ";" + str(nb_takenpaths) + ";" + str(time.time()-start) + "\n")
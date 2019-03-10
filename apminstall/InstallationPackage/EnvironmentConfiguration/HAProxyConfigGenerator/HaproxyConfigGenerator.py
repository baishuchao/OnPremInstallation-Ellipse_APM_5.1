import sys
import getopt
import os
import json
import logging
from collections import OrderedDict

# defaults
haproxyConfigsFolderName = 'EnvironmentsConfigs'
environmentConfigsPath = haproxyConfigsFolderName
commonConfigurationFile = 'CommonConfig'
serversListFile = 'ServersList.json'

# global variables
configDataSource = dict()
domainsAndCerts = dict()
services = dict()
aclHosts = list()
mapping = list()
backendServicePorts = dict()
serversWithIPs = dict()
commonConfig = str
domainsList = list()
portsList = list()


def main(argv):
    global environmentConfigsPath
    global commonConfigurationFile
    global serversListFile

    logging.basicConfig(format='%(levelname)s:%(message)s',
                        level=logging.DEBUG)

    try:
        opts, args = getopt.getopt(
            argv, "hc:e:s:", ['commonConfigFile=', 'environmentConfigsPath=', 'serversListJson='])
    except getopt.GetoptError as err:
        print str(err)
        sys.exit(1)
    if(len(opts) == 0):
        print 'No parameters passed. Taking default\'s..'
        print 'Add -h parameter for details.\n'
    for opt, arg in opts:
        if opt == '-h':
            print 'Things needed to create HAProxy configuration file:'
            print '1. CommonConfig - path to file with common configuration (globals, defaults, frontend, ssl\'s). By default - {} in the same folder.'.format(
                commonConfigurationFile)
            print '2. ServersList - path to json file with list of server names and their IP\'s. By default - {} in the same folder.'.format(
                serversListFile)
            print '3. Folder with environment configurations json\'s - files in this folder contains data as list of services with domain and certificates and port number. By default in the same foler ({}).'.format(
                haproxyConfigsFolderName)
            print '\nUsage'
            print '{fileName} -c <commonConfigFile> -e <environmentConfigsPath> -s <serversListJson>'.format(
                fileName=os.path.basename(__file__))
            print '\nParameters'
            print '-c or --commonConfigFile - point the file with common configuration'
            print '-e or --environmentConfigsPath - points the folder with environments configuration files'
            print '-s or --serversListJson - points the json file with list of server and IP\'s'

            sys.exit()
        elif opt in ("-c", "--commonConfigFile"):
            if not arg is None:
                if not isFileValid(arg):
                    print 'Invalid path to common config file given. Exiting..'
                    sys.exit()
                commonConfigurationFile = arg
        elif opt in ("-e", "--environmentConfigsPath"):
            if not arg is None:
                if not isPathValid(arg):
                    print 'No environmentConfigsPath valid path given. Exiting..'
                    sys.exit()
                environmentConfigsPath = arg
        elif opt in ("-s", "--serversListJson"):
            if not arg is None:
                if not isFileValid(arg):
                    print 'Invalid path to servers list file given. Exiting..'
                    sys.exit()
                serversListFile = arg

    readJsonConfigurationFiles()
    prepareHostsAndMappings()
    getServersList()
    getCommonConfiguration()
    if validateDomainsAndPorts():
        createHaproxyConfigurationFile()
    else:
        print 'HAProxy configuration file has not beed created - domain or port duplication found.'


def isFileValid(pathStr):
    try:
        if os.path.exists(pathStr):
            return True
        else:
            return False
    except os.error:
        print os.error
        return False


def isPathValid(pathStr):
    try:
        if os.path.isdir(pathStr):
            return True
        else:
            return False
    except os.error:
        print os.error
        return False


def readJsonConfigurationFiles():
    global configDataSource
    global domainsAndCerts
    global services

    print 'Getting json configuration files in {path}'.format(
        path=environmentConfigsPath)
    jsonFiles = [jsonFile for jsonFile in os.listdir(
        environmentConfigsPath) if(jsonFile.endswith('.json'))]

    if len(jsonFiles) != 0:
        print 'Got {files}'.format(files=','.join(jsonFiles))
        for jsonFile in jsonFiles:
            relativePath = os.path.join(environmentConfigsPath, jsonFile)
            fileName = os.path.basename(relativePath)
            environmentName = fileName.rsplit('.', 1)[0]

            print 'Reading data from {jsonFile}...'.format(jsonFile=jsonFile)
            try:
                with open(relativePath, 'r') as filee:
                    services.clear()
                    domainsAndCerts.clear()
                    data = dict(json.load(filee))
                    filee.close()
            except IOError:
                print 'Failed to open file {}'.format(fileName)
                print 'Terminating..'
                sys.exit(1)
            try:
                for key, value in data['services'].items():
                    serviceName = key
                    servicePort = value['port']
                    portsList.append(servicePort)
                    for k, v in value['domainsAndCerts'].items():
                        domainsAndCerts[k] = v
                        domainsList.append(k)
                    services[serviceName] = {
                        'domainsAndCerts': domainsAndCerts, 'port': servicePort}
                    domainsAndCerts = dict()
                configDataSource[environmentName] = services.copy()
            except KeyError:
                print 'File does not contain proper data. Omitting...'
                continue
    else:
        logging.warning('No cofiguration files found..')
        print 'Terminating..'
        sys.exit()


def prepareHostsAndMappings():
    global mapping
    global aclHosts
    global backendServicePorts

    print 'Preparing acl hosts and mappings..'
    try:
        for environment, services in configDataSource.items():
            for service, configurationData in services.items():
                for domain, cert in configurationData['domainsAndCerts'].items():
                    hostStr = 'host_{hostName}'.format(
                        hostName=environment+'_'+service)
                    backendStr = '{environment}_{service}_back'.format(
                        environment=environment, service=service)
                    aclStr = 'acl {hostName} hdr_dom(host) -i {domain}'.format(
                        hostName=hostStr, domain=domain)
                    mappingStr = 'use_backend {backendName} if {hostName}'.format(
                        backendName=backendStr, hostName=hostStr)
                    aclHosts.append(aclStr)
                    if mappingStr not in mapping:
                        mapping.append(mappingStr)
                    backendServicePorts[backendStr] = configurationData['port']
    except KeyError:
        print 'Error while preparing data..'
        sys.exit(1)
    except IOError:
        print 'Failed to open file.'
        print 'Terminating..'
        sys.exit(1)
    print 'Done'


def getServersList():
    global serversWithIPs
    print 'Getting list of servers..'
    try:
        with open(serversListFile, 'r') as servers:
            serversData = dict(json.load(servers))
            serversWithIPs = OrderedDict(sorted(serversData.items()))
            servers.close()
    except IOError:
        print "Failed to open file {}".format(serversListFile)
        print 'Terminating..'
        sys.exit(1)
    print 'Done'


def getCommonConfiguration():
    global commonConfigurationFile
    global commonConfig
    print 'Reading common configuration..'
    with open(commonConfigurationFile, 'r') as commonConfigFile:
        commonConfig = commonConfigFile.read()
        commonConfigFile.close()
    print 'Done'


def createHaproxyConfigurationFile():
    print 'Generating haproxy configuration file..'
    haproxyConfigFileName = 'HaproxyConfig.cfg'
    sortedBackendServicePorts = OrderedDict(
        sorted(backendServicePorts.items()))
    with open(haproxyConfigFileName, 'w') as haproxyConfig:
        haproxyConfig.write(commonConfig+'\n')
        for aclHost in sorted(aclHosts):
            haproxyConfig.write('\t'+aclHost+'\n')
        haproxyConfig.write('\n')
        for mapHost in sorted(mapping):
            haproxyConfig.write('\t'+mapHost+'\n')
        haproxyConfig.write('\n')
        for backend, port in sortedBackendServicePorts.items():
            haproxyConfig.write('backend ' + backend + '\n')
            haproxyConfig.write('\tbalance roundrobin\n')
            for server, ip in serversWithIPs.items():
                haproxyConfig.write('\tserver ' + server +
                                    ' ' + ip + ':' + str(port) + ' check\n')
            haproxyConfig.write('\n')
        haproxyConfig.close()
    print 'Done'
    print 'Configuration file {fileName} saved.'.format(
        fileName=haproxyConfigFileName)


def validateDomainsAndPorts():
    print 'Validating data..'
    # Done intentionally - if called in condition not always function is called
    validDomains = validateDomains()
    validPorts = validatePorts()
    valid = (validDomains and validPorts)
    return valid


def validateDomains():
    if len(domainsList) == len(set(domainsList)):
        print 'Domains OK.'
        return True
    else:
        print 'Duplicated domains found:'
        duplicatedDomains = list(
            set([x for x in domainsList if domainsList.count(x) > 1]))
        getDuplicatedDomainsDetails(set(duplicatedDomains))
        return False


def getDuplicatedDomainsDetails(listOfDuplications):
    for environment, services in configDataSource.items():
        for service, serviceData in services.items():
            for domain, certs in serviceData['domainsAndCerts'].items():
                if domain in listOfDuplications:
                    print '{environment}: {service} - {domain}'.format(
                        environment=environment, service=service, domain=domain)


def validatePorts():
    if len(portsList) == len(set(portsList)):
        print 'Ports OK.'
        return True
    else:
        print 'Duplicated ports found:'
        duplicatedPorts = list(
            set([x for x in portsList if portsList.count(x) > 1]))
        getDuplicatedPortsDetails(duplicatedPorts)
        return False


def getDuplicatedPortsDetails(listOfDuplicatedPorts):
    for environment, services in configDataSource.items():
        for service, serviceData in services.items():
            if serviceData['port'] in listOfDuplicatedPorts:
                print '{environment}: {service} - {port}'.format(
                    environment=environment, service=service, port=serviceData['port'])


if __name__ == "__main__":
    main(sys.argv[1:])

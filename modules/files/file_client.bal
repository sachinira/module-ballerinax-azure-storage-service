// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/file;
import ballerina/http;
import ballerina/xmldata;

# Azure Storage File Client.
# 
# + httpClient - HTTP Client for Azure Storage File Service
# + azureConfig - Azure file service configuration
@display {label: "Azure Storage File Client", iconPath: "AzureStorageFileLogo.png"}
public client class FileClient {
    private http:Client httpClient;
    private AzureFileServiceConfiguration azureConfig;

    # Initalize Azure Client using the provided azureConfiguration by user
    #
    # + azureConfig - AzureFileServiceConfiguration record
    public isolated function init(AzureFileServiceConfiguration azureConfig) returns error? {
        http:ClientSecureSocket? secureSocketConfig = azureConfig?.secureSocketConfig;
        string baseURL = string `https://${azureConfig.accountName}.file.core.windows.net/`;
        self.azureConfig = azureConfig;
        if (secureSocketConfig is http:ClientSecureSocket) {
            self.httpClient = check new (baseURL, {
                http1Settings: {chunking: http:CHUNKING_NEVER},
                secureSocket: secureSocketConfig
            });
        } else {
            self.httpClient = check new (baseURL, {http1Settings: {chunking: http:CHUNKING_NEVER}});
        }
    }

    # Lists directories within the share or specified directory. 
    #
    # + fileShareName - Name of the FileShare
    # + azureDirectoryPath - Path of the Azure directory
    # + uriParameters - Map of the optional URI parameters record
    # + return -  If success, returns DirectoryList record with Details and the marker.  Else returns error.
    @display {label: "Get Directory list"}
    remote isolated function getDirectoryList(@display {label: "File share name"} string fileShareName, 
                                              @display {label: "Azure Directory path"} string? azureDirectoryPath = (), 
                                              @display {label: "Optional URI parameters map"} GetFileListURIParamters 
                                              uriParameters = {}) returns @tainted @display {label: "Directory List"} 
                                              DirectoryList|error {
        string requestPath = azureDirectoryPath is () ? (SLASH + fileShareName + SLASH + LIST_FILES_DIRECTORIES_PATH) 
            : SLASH + fileShareName + SLASH + azureDirectoryPath + SLASH + LIST_FILES_DIRECTORIES_PATH;
        string? optionalURIParameters = setOptionalURIParametersFromRecord(uriParameters);
        requestPath = optionalURIParameters is () ? requestPath : (requestPath + optionalURIParameters);
        http:Request request = new;
        if (self.azureConfig.authorizationMethod == ACCESS_KEY) {
            map<string> requiredURIParameters = {};
            requiredURIParameters[RESTYPE] = DIRECTORY;
            requiredURIParameters[COMP] = LIST;
            string resourcePathForSharedkeyAuth = azureDirectoryPath is () ? (fileShareName + SLASH) 
                : (fileShareName + SLASH + azureDirectoryPath + SLASH);
            AuthorizationDetail  authorizationDetail = {
                azureRequest:request,
                azureConfig:self.azureConfig,
                httpVerb: http:HTTP_GET,
                uriParameterRecord: uriParameters,
                resourcePath: resourcePathForSharedkeyAuth,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);       
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        map<string> headerMap = populateHeaderMapFromRequest(request);
        http:Response response = <http:Response>check self.httpClient->get(<@untainted>requestPath, headerMap);
        if (response.statusCode === http:STATUS_OK ) {
            xml responseBody = check response.getXmlPayload();
            xml formattedXML = responseBody/<Entries>/<Directory>;
            if (formattedXML.length() === 0) {
                fail error(NO_DIRECTORIES_FOUND);
            }
            json convertedJsonContent = check xmldata:toJson(formattedXML);
            return <DirectoryList> check convertedJsonContent.cloneWithType(DirectoryList);
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Lists files within the share or specified directory.
    #
    # + fileShareName - Name of the FileShare
    # + azureDirectoryPath - Path of the Azure directory
    # + uriParameters - Map of the optional URI parameters record
    # + return -  If success, returns FileList record with Details and the marker.  Else returns error
    @display {label: "Get file list"}
    remote isolated function getFileList(@display {label: "File share name"} string fileShareName, 
                                         @display {label: "Azure directory path"} string? azureDirectoryPath = (), 
                                         @display {label: "Optional URI parameters"} GetFileListURIParamters 
                                         uriParameters = {}) returns @tainted @display {label: "File list"} FileList|
                                         error {
        string requestPath = azureDirectoryPath is () ? (SLASH + fileShareName + SLASH + LIST_FILES_DIRECTORIES_PATH) 
            : (SLASH + fileShareName + SLASH + azureDirectoryPath + SLASH + LIST_FILES_DIRECTORIES_PATH);
        string? optinalURIParameters = setOptionalURIParametersFromRecord(uriParameters);
        requestPath = optinalURIParameters is () ? requestPath : (requestPath + optinalURIParameters);
        http:Request request = new;
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters = {};
            requiredURIParameters[RESTYPE] = DIRECTORY;
            requiredURIParameters[COMP] = LIST;
            string resourcePathForSharedkeyAuth = azureDirectoryPath is () ? (fileShareName + SLASH) 
                : (fileShareName + SLASH + azureDirectoryPath + SLASH);
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_GET,
                uriParameterRecord: uriParameters,
                resourcePath: resourcePathForSharedkeyAuth,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);        
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        map<string> headerMap = populateHeaderMapFromRequest(request);
        http:Response response = <http:Response> check self.httpClient->get(<@untainted>requestPath, headerMap);
        if (response.statusCode === http:STATUS_OK ) {
            xml responseBody = check response.getXmlPayload();
            xml formattedXML = responseBody/<Entries>/<File>;
            if (formattedXML.length() === 0) {
                fail error(NO_FILE_FOUND);
            }
            json convertedJsonContent = check xmldata:toJson(formattedXML);
            return <FileList>check convertedJsonContent.cloneWithType(FileList);
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Creates a directory in the share or parent directory.
    #
    # + fileShareName - Name of the fileshare
    # + newDirectoryName - New directory name in azure
    # + azureDirectoryPath - Path to the new directory
    # + return - If success, returns true.  Else returns error
    @display {label: "Create directory"}
    remote isolated function createDirectory(@display {label: "File share name"} string fileShareName, 
                                             @display {label: "New directory name"} string newDirectoryName, 
                                             @display {label: "Azure directory path"} string? azureDirectoryPath = ()) 
                                             returns @tainted @display {label: "Directory created"} boolean|error {
        string requestPath = SLASH + fileShareName;
        requestPath = azureDirectoryPath is () ? requestPath : (requestPath + SLASH + azureDirectoryPath);
        requestPath = requestPath + SLASH + newDirectoryName + CREATE_DELETE_DIRECTORY_PATH;
        http:Request request = new;
        map<string> requiredHeaders = {
            [X_MS_FILE_PERMISSION]: INHERIT,
            [x_MS_FILE_ATTRIBUTES]: DIRECTORY,
            [X_MS_FILE_CREATION_TIME]: NOW,
            [X_MS_FILE_LAST_WRITE_TIME]: NOW
        };
        setSpecficRequestHeaders(request, requiredHeaders);
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters = {}; 
            requiredURIParameters[RESTYPE] = DIRECTORY;
            string resourcePathForSharedkeyAuth = azureDirectoryPath is () ? (fileShareName + SLASH + newDirectoryName) 
                : (fileShareName + SLASH + azureDirectoryPath + SLASH + newDirectoryName);
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_PUT,
                resourcePath: resourcePathForSharedkeyAuth,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);       
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        http:Response response = <http:Response> check self.httpClient->put(requestPath, request);
        if (response.statusCode === http:STATUS_CREATED) {
            return true;
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Deletes the directory. Only supported for empty directories.
    #
    # + fileShareName - Name of the FileShare
    # + directoryName - Name of the Direcoty to be deleted
    # + azureDirectoryPath - Path of the Azure directory
    # + return - If success, returns true.  Else returns error
    remote isolated function deleteDirectory(@display {label: "File share name"} string fileShareName, 
                                             @display {label: "Directory name"} string directoryName, 
                                             @display {label: "Azure directory path"} string? azureDirectoryPath = ()) 
                                             returns @tainted @display {label: "Directory deleted"} boolean|error {
        string requestPath = SLASH + fileShareName;
        requestPath = azureDirectoryPath is () ? requestPath : (requestPath + SLASH + azureDirectoryPath);
        requestPath = requestPath + SLASH + directoryName + CREATE_DELETE_DIRECTORY_PATH;
        http:Request request = new;
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters ={}; 
            requiredURIParameters[RESTYPE] = DIRECTORY;
            string resourcePathForSharedkeyAuth = azureDirectoryPath is () ? (fileShareName + SLASH + directoryName) 
                : (fileShareName + SLASH + azureDirectoryPath + SLASH + directoryName);
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_DELETE,
                resourcePath: resourcePathForSharedkeyAuth,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);       
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        http:Response response = <http:Response>check self.httpClient->delete(requestPath, request);
        if (response.statusCode === http:STATUS_ACCEPTED) {
            return true;
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Creates a new file or replaces a file. This operation only initializes a file. putRange should be used to add 
    # content.
    #
    # + fileShareName - Name of the fileShare
    # + newFileName - Name of the file
    # + fileSizeInByte - Size of the file in Bytes
    # + azureDirectoryPath - Path of the Azure directory 
    # + return - If success, returns true.  Else returns error
    @display {label: "Create a file"}
    remote isolated function createFile(@display {label: "File share name"} string fileShareName, 
                                        @display {label: "Name of the file"} string newFileName, 
                                        @display {label: "File size"} int fileSizeInByte, 
                                        @display {label: "Azure directory path"} string? azureDirectoryPath = ()) 
                                        returns @tainted @display {label: "File created"} boolean|error {
        return createFileInternal(self.httpClient, fileShareName, newFileName, fileSizeInByte, self.azureConfig, 
            azureDirectoryPath);
    }

    # Writes the content (a range of bytes) to a file initialized earlier.
    #
    # + fileShareName - Name of the FileShare
    # + localFilePath - Path of the local file
    # + azureFileName - Name of the file in azure
    # + azureDirectoryPath - Path of the azure directory
    # + return - If success, returns true.  Else returns error
    @display {label: "Write content to file"}
    remote function putRange(@display {label: "File share name"} string fileShareName,
                             @display {label: "Local file path"} string localFilePath, 
                             @display {label: "Name of the file in azure"} string azureFileName, 
                             @display {label: "Azure directory path"} string? azureDirectoryPath = ()) 
                             returns @tainted @display {label: "Status"} boolean|error {
        file:MetaData fileMetaData = check file:getMetaData(localFilePath);
        int fileSizeInByte = fileMetaData.size;
        return check putRangeInternal(self.httpClient, fileShareName, localFilePath, azureFileName, self.azureConfig, 
            fileSizeInByte, azureDirectoryPath);
    }

    # Provides a list of valid ranges (in bytes) of a file.
    #
    # + fileShareName - Name of the FileShare
    # + fileName - Name of the file
    # + azureDirectoryPath - Path of the Azure directory
    # + return - If success, returns RangeList record.  Else returns error
    @display {label: "Get list of valid ranges of a file"}
    remote isolated function listRange(@display {label: "File share name"} string fileShareName, 
                                       @display {label: "Name of the file"} string fileName, 
                                       @display {label: "Azure directory path"} string? azureDirectoryPath = ()) 
                                       returns @tainted @display {label: "Range list"} RangeList|error {
        string requestPath = azureDirectoryPath is () ? (SLASH + fileShareName + SLASH + fileName + QUESTION_MARK 
            + LIST_FILE_RANGE) : (SLASH + fileShareName + SLASH + azureDirectoryPath + SLASH + fileName + QUESTION_MARK 
            + LIST_FILE_RANGE);
        http:Request request = new();
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters ={}; 
            requiredURIParameters[COMP] = RANGE_LIST;
            string resourcePathForSharedkeyAuth = azureDirectoryPath is () ? (fileShareName + SLASH + fileName) 
                : (fileShareName + SLASH + azureDirectoryPath + SLASH + fileName);
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_GET,
                resourcePath: resourcePathForSharedkeyAuth,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);     
        } else {
            requestPath = requestPath.concat(AMPERSAND, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        map<string> headerMap = populateHeaderMapFromRequest(request);
        http:Response response = <http:Response>check self.httpClient->get(requestPath, headerMap);
        if (response.statusCode === http:STATUS_OK ) {
            xml responseBody = check response.getXmlPayload();
            if (responseBody.length() === 0) {
                fail error(NO_RANAGE_LIST_FOUND);
            }
            json convertedJsonContent = check xmldata:toJson(responseBody);
            return <RangeList> check convertedJsonContent.cloneWithType(RangeList);
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Deletes a file from the fileshare.
    #
    # + fileShareName - Name of the FileShare
    # + fileName - Name of the file
    # + azureDirectoryPath - Path of the Azure directory
    # + return - If success, returns true.  Else returns error
    @display {label: "Delete a file"}
    remote isolated function deleteFile(@display {label: "File share name"} string fileShareName, 
                                        @display {label: "File name"} string fileName, 
                                        @display {label: "Azure directory path"} string? azureDirectoryPath = ()) 
                                        returns @tainted @display {label: "File deleted"} boolean|error {
        http:Request request = new;
        string requestPath = SLASH + fileShareName;
        requestPath = azureDirectoryPath is () ? requestPath : (requestPath + SLASH + azureDirectoryPath);
        requestPath = requestPath + SLASH + fileName;
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters ={}; 
            string resourcePathForSharedkeyAuth = azureDirectoryPath is () ? (fileShareName + SLASH + fileName) 
                : (fileShareName + SLASH + azureDirectoryPath + SLASH + fileName);
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_DELETE,
                resourcePath: resourcePathForSharedkeyAuth,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);      
        } else {
            requestPath = requestPath.concat(QUESTION_MARK, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        http:Response response = <http:Response>check self.httpClient->delete(requestPath, request);
        if (response.statusCode === http:STATUS_ACCEPTED) {
            return true;
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Downloads a file from fileshare to a specified location.
    #
    # + fileShareName - Name of the FileShare
    # + fileName - Name of the file
    # + azureDirectoryPath - Path of azure directory
    # + localFilePath - Path to the local destination location
    # + return -  If success, returns true.  Else returns error
    @display {label: "Download a file"}
    remote isolated function getFile(@display {label: "File share name"} string fileShareName, 
                                     @display {label: "File name"} string fileName, 
                                     @display {label: "Local file path to download"} string localFilePath, 
                                     @display {label: "Azure directory path"} string? azureDirectoryPath = ()) 
                                     returns @tainted @display {label: "Download Status"} boolean|error {
        string requestPath = azureDirectoryPath is () ? (SLASH + fileShareName + SLASH + fileName) : (SLASH 
            + fileShareName + SLASH + azureDirectoryPath + SLASH + fileName);    
        http:Request request = new;
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters ={}; 
            string resourcePathForSharedkeyAuth = azureDirectoryPath is () ? (fileShareName + SLASH + fileName) 
                : (fileShareName + SLASH + azureDirectoryPath + SLASH + fileName);
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_GET,
                resourcePath: resourcePathForSharedkeyAuth,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);      
        } else {
            requestPath = requestPath.concat(QUESTION_MARK, self.azureConfig.accessKeyOrSAS.substring(1)); 
        }
        map<string> headerMap = populateHeaderMapFromRequest(request);
        http:Response response = <http:Response> check self.httpClient->get(requestPath, headerMap);
        if (response.statusCode === http:STATUS_OK ) {
            byte[] responseBody = check response.getBinaryPayload();
            if (responseBody.length() === 0) {
                fail error(AN_EMPTY_FILE_FOUND);
            }
            return writeFile(localFilePath, responseBody);
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Copies a file to another location in fileShare. 
    #
    # + fileShareName - Name of the fileShare
    # + sourceURL - source file url in the fileShare
    # + destFileName - Name of the destination file
    # + destDirectoryPath - Path of the destination in fileShare
    # + return - If success, returns true.  Else returns error
    @display {label: "Copy a file to another location in fileshare"}
    remote isolated function copyFile(@display {label: "File share name"} string fileShareName, 
                                      @display {label: "Source file URL"} string sourceURL, 
                                      @display {label: "Destination file name"} string destFileName, 
                                      @display {label: "Destination directory path"} string? destDirectoryPath = ()) 
                                      returns @tainted @display {label: "File copied"} boolean|error {
        string requestPath = destDirectoryPath is () ? (SLASH + fileShareName + SLASH + destFileName) 
            : (SLASH + fileShareName + SLASH + destDirectoryPath + SLASH + destFileName);
        string sourcePath = sourceURL;
        if (self.azureConfig.authorizationMethod === SAS) {
            sourcePath = sourceURL + self.azureConfig.accessKeyOrSAS;
        }
        http:Request request = new;
        map<string> requiredSpecificHeaderes = {[X_MS_COPY_SOURCE]: sourcePath};
        setSpecficRequestHeaders(request, requiredSpecificHeaderes);
        if (self.azureConfig.authorizationMethod === ACCESS_KEY) {
            map<string> requiredURIParameters = {}; 
            string resourcePathForSharedkeyAuth = destDirectoryPath is () ? (fileShareName + SLASH + destFileName) 
                : (fileShareName + SLASH + destDirectoryPath + SLASH + destFileName);
            AuthorizationDetail  authorizationDetail = {
                azureRequest: request,
                azureConfig: self.azureConfig,
                httpVerb: http:HTTP_PUT,
                resourcePath: resourcePathForSharedkeyAuth,
                requiredURIParameters: requiredURIParameters
            };
            check prepareAuthorizationHeaders(authorizationDetail);       
        } else {
            requestPath = requestPath.concat(self.azureConfig.accessKeyOrSAS); 
        }
        http:Response response = <http:Response> check self.httpClient->put(requestPath, request);
        if (response.statusCode === http:STATUS_ACCEPTED) {
            return true;
        } else {
            fail error(check getErrorMessage(response));
        }
    }

    # Upload a file directly into the fileshare.
    # 
    # + fileShareName - Name of the fileShare
    # + localFilePath - The path of the file to be uploaded
    # + azureFileName - The name of the file in Azure
    # + azureDirectoryPath - Directory path in Azure
    # + return - If success, returns true.  Else returns error
    remote function directUpload(@display {label: "File share name"} string fileShareName, 
                                 @display {label: "Local file path"} string localFilePath, 
                                 @display {label: "File name in Azure"} string azureFileName, 
                                 @display {label: "Azure directory path"} string? azureDirectoryPath = ()) 
                                 returns @tainted @display {label: "File uploaded"} boolean|error {
        file:MetaData fileMetaData = check file:getMetaData(localFilePath);
        int fileSizeInByte = fileMetaData.size;
        var createFileResponse = self->createFile(fileShareName, azureFileName, fileSizeInByte, azureDirectoryPath);
        if (createFileResponse === true) {
            var uploadResult = putRangeInternal(self.httpClient, fileShareName, localFilePath, azureFileName, 
                self.azureConfig, fileSizeInByte, azureDirectoryPath);
            return uploadResult;
        } else {
            return createFileResponse;
        }
    }
}

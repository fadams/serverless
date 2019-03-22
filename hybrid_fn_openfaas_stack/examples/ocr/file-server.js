#!/usr/bin/env node
/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 *
 */

/**
 * file-server.js is a simple node.js HTTP file server. It is primarily intended
 * for local, non-production use and hasn't been tested for robustness against
 * any sort of attack.
 */

var http = require("http");
var url = require("url");
var path = require("path");
var fs = require("fs");
var port = process.argv[2] || 8080;

var contentTypesByExtension = {
    '.htm': "text/html",
    '.html': "text/html",
    '.txt': "text/plain",
    '.asc': "text/plain",
    '.xml': "text/xml",
    '.css':  "text/css",
    '.htc':  "text/x-component",
    '.gif':  "image/gif",
    '.jpg':  "image/jpeg",
    '.jpeg':  "image/jpeg",
    '.png':  "image/png",
    '.ico':  "image/x-icon",
    '.mp3':  "audio/mpeg",
    '.m3u':  "audio/mpeg-url",
    '.mov':  "video/quicktime",
    '.divx':  "video/divx",
    '.mp4':  "video/mp4",
    '.m4v':  "video/x-m4v",
    '.avi':  "video/x-msvideo",
    '.asf':  "video/x-ms-asf",
    '.wma':  "video/x-ms-wma",
    '.wmv':  "video/x-ms-wmv",
    '.js':   "application/x-javascript",
    '.pdf':   "application/pdf",
    '.doc':   "application/msword",
    '.ppt':   "application/mspowerpoint",
    '.xls':   "application/excel",
    '.ogg':   "application/x-ogg",
    '.zip':   "application/octet-stream",
    '.exe':   "application/octet-stream",
    '.class':   "application/octet-stream"
};

/**
 * Renders a number in a more "human readable" format providing a bytes/KB/MB/GB
 * format depending on the size.
 *
 * @param {number} number the number to be rendered.
 * @returns {string} a String representation of the number in a more human readable form.
 */
var renderNumber = function(number) {
    if (number < 1000) {
        return number + " bytes";
    } else if (number < 1000000) {
        number /= 1000;
        return number.toFixed(1) + " KB";
    } else if (number < 1000000000) {
        number /= 1000000;
        return number.toFixed(1) + " MB";
    } else {
        number /= 1000000000;
        return number.toFixed(1) + " GB";
    }
};

var serveFile = function(response, filename) {
    // TODO Use Range header allow download resuming.
    var headers = {};
    var contentType = contentTypesByExtension[path.extname(filename).toLowerCase()];

    if (contentType) {
        headers["Content-Type"] = contentType;
    } else {
        headers["Content-Type"] = "application/octet-stream";
    }
//console.log(headers);

    var firstChunk = true;
    var filestream = fs.createReadStream(filename);

    response.writeHead(200, headers);
    filestream.pipe(response);
};

var serveDirectory = function(response, filename, uri) {
    // If the directory name doesn't end in "/" append it to the URI.
    if (uri.indexOf('/', uri.length - 1) === -1) {
        uri += '/';
    }

    var html = "<html><body><h1>Directory " + uri + "</h1><br/>";

    if (uri.length > 1) {
        html += "<b><a href=\"" + path.join(uri, "..") + "\">..</a></b><br/>";
    }

    var directoryHTML = "";
    var fileHTML = "";
    var files = fs.readdirSync(filename);

    for (var i = 0; i < files.length; i++) {
        var name = files[i];
        var current = path.join(filename, name);
        var stat = fs.statSync(current);

        if (stat.isDirectory()) {
            directoryHTML +=  "<b><a href=\"" + encodeURI(uri + name + "/") + "\">" + name + "</a><br/></b>";
        } else if (stat.isFile()) {
            fileHTML +=  "<a href=\"" + encodeURI(uri + name) + "\">" + name + "</a>" +
                         " &nbsp;<font size=2>(" + renderNumber(stat.size) + ")</font><br/>";
        }
    }

    html += directoryHTML + fileHTML + "</body></html>";
    response.writeHead(200, {"Content-Type": "text/html"});
    response.write(html);
    response.end();
    return;
};

http.createServer(function(request, response) {
//console.log(request.headers);
    var uri = decodeURI(url.parse(request.url).pathname);
    var filename = path.join(process.cwd(), uri);

    fs.exists(filename, function(exists) {
        if (!exists) {
            response.writeHead(404, {"Content-Type": "text/plain"});
            response.write("404 Not Found\n");
            response.end();
            return;
        }

        if (fs.statSync(filename).isDirectory()) {
            // First try index.html and index.htm
            if (fs.existsSync(filename + "/index.html")) {
                serveFile(response, filename + "/index.html");
            } else if (fs.existsSync(filename + "/index.htm")) {
                serveFile(response, filename + "/index.htm");
            } else { // No index file, list the directory
                serveDirectory(response, filename, uri);
            }
        } else {
            serveFile(response, filename);
        }
    });
}).listen(parseInt(port, 10));

console.log("File server running on http://localhost:" + port + "/\nCTRL + C to shutdown");


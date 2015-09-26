var formidable = require('formidable'),
    http = require('http'),
    exec = require('exec'),
    util = require('util');
var child_process = require('child_process');
var sanitize = require("sanitize-filename");
var config = require("./config");

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g,
        function (a, b) {
            var r = o[b];
            return typeof r === 'string' || typeof r === 'number' ? r : a;
        }
    );
};

var str = 'sudo lpadmin -p "{id}" -v lpd://{id}@printing.andrew.cmu.edu/andrew -P /home/ubuntu/workspace/CMUGeneric.ppd; sudo cupsenable {id}; sudo cupsaccept {id}; sudo lp -d "{id}" -t "{filename}" {path}';
//var printStr = 'lp -d "{id}" test.pdf';

function deleteFile(path, filename){
    child_process.exec('rm "{path}"'.supplant({path: path}), function(err, out, code) {
      if(!err && code == 0){
          console.log("Deleted file {filename}".supplant({filename: filename}));
      }
      else{
          console.log("Error deleting {filename}".supplant({filename: filename}));
      }
    });
}

http.createServer(function(req, res) {
  if (req.url == '/print' && req.method.toLowerCase() == 'post') {
    // parse a file upload
    var form = new formidable.IncomingForm({
        uploadDir: "/home/ubuntu/workspace/uploads",
        keepExtensions: true,
        type: 'multipart',
        multiples: 'md5'
    });
    
    form.parse(req, function(err, fields, files) {
      //res.writeHead(200, {'content-type': 'text/plain'});
      //res.write('received upload:\n\n');
      //console.log(util.inspect({fields: fields, files: files}));
      if(files && files.file && files.file.path && files.file.name)
        console.log("Received file {filename}".supplant({filename: files.file.name}));
      if(fields && fields.id && files && files.file && files.file.path && files.file.name){
          //Sanitize Data
          files.file.name = sanitize(files.file.name).trim();
          fields.id = fields.id.trim();
          if(fields.id.length >= 2 && fields.id.length <= 8 && /^[a-z0-9]+$/i.test(fields.id)){
               child_process.exec(str.supplant({ id: fields.id, path: files.file.path, filename: files.file.name}), function(err, out, code) {
                  if(!err && code == 0){
                      console.log("Printed file {filename} from Andrew ID {id}! ".supplant({id: fields.id, filename: files.file.name}) + out.substring(0, out.length - 1));
                      res.writeHead(200, { 'Content-Type': 'application/json' });
                      res.write(JSON.stringify({
                          id: fields.id,
                          filename: files.file.name,
                          out: out.substring(0, out.length - 1)
                      }));
                      res.end();
                  }
                  else{
                      console.log("Error printing file: " + err);
                      res.writeHead(400, { 'Content-Type': 'application/json' });
                      res.write(JSON.stringify({
                          err: err
                      }));
                      res.end();
                  }
                  deleteFile(files.file.path, files.file.name);
              });
          }
          else{
              if(files && files.file && files.file.path && files.file.name){
                 deleteFile(files.file.path, files.file.name);
              }
              res.writeHead(400, { 'Content-Type': 'application/json' });
              res.write(JSON.stringify({
                  err: "Invalid fields!"
              }));
              res.end();
          }

      }
      else{
          if(files && files.file && files.file.path && files.file.name){
             deleteFile(files.file.path, files.file.name);
          }
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.write(JSON.stringify({
              err: "Missing fields!"
          }));
          res.end();
      }
    });

    return;
  }
}).listen(process.env.PORT || 8080);
console.log('Print server running on port ' + (process.env.PORT || 8080));

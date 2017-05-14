const fs = require('fs');
const path = require('path');
const readdir = require('recursive-readdir-sync');

module.exports.list = () => readdir(path.join(__dirname, 'schemas'));

module.exports.names = list => list.map(f => JSON.parse(fs.readFileSync(path.join(f))).id);

module.exports.load = (list, schemaManager) => schemaManager.addSchema(
  list.map(f =>
    JSON.parse(fs.readFileSync(path.join(f)))
  )
);

module.exports = {
  apps: [{
    script: './bin/server/reactory/index.js',
    instances: 'max',
    exec_mode: 'cluster'
  }]
};

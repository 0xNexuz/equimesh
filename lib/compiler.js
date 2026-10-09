const fs = require('node:fs');
const path = require('node:path');
const solc = require('solc');

function compileContracts(contractsDir = path.join(__dirname, '..', 'contracts')) {
  const sources = {};
  
  function readDirRecursive(dir) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
      const fullPath = path.join(dir, file);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        readDirRecursive(fullPath);
      } else if (file.endsWith('.sol')) {
        const relativePath = path.relative(contractsDir, fullPath).replace(/\\/g, '/');
        sources[relativePath] = {
          content: fs.readFileSync(fullPath, 'utf8')
        };
      }
    }
  }

  readDirRecursive(contractsDir);

  const input = {
    language: 'Solidity',
    sources: sources,
    settings: {
      evmVersion: 'paris',
      optimizer: {
        enabled: true,
        runs: 200
      },
      outputSelection: {
        '*': {
          '*': ['abi', 'evm.bytecode']
        }
      }
    }
  };

  const output = JSON.parse(solc.compile(JSON.stringify(input)));

  if (output.errors) {
    const errors = output.errors.filter(e => e.severity === 'error');
    if (errors.length > 0) {
      const msgs = errors.map(e => e.formattedMessage).join('\n');
      throw new Error(`Solidity compilation failed:\n${msgs}`);
    }
  }

  return output.contracts;
}

if (require.main === module) {
  try {
    const compiled = compileContracts();
    console.log('Compilation successful! Compiled contracts:');
    for (const [file, contracts] of Object.entries(compiled)) {
      console.log(` - ${file}: ${Object.keys(contracts).join(', ')}`);
    }
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = { compileContracts };

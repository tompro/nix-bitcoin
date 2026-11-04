// Regression fixture: make backup write callbacks slower than the old
// one-second test sleep, without altering the writes or their results.
// Used only by the RTL package's backup-concurrency test, never at runtime.
import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';

const writeFile = fs.writeFile;
fs.writeFile = function (path, ...args) {
  if (String(path).includes('channel-all.bak.') && String(path).endsWith('.tmp')) {
    const callback = args.pop();
    return writeFile.call(this, path, ...args, (...result) => {
      setTimeout(() => callback(...result), 1500);
    });
  }
  return writeFile.call(this, path, ...args);
};
syncBuiltinESMExports();

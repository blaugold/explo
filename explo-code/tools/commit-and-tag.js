const { execSync } = require('child_process')
const path = require('path')

const pkg = require(path.resolve(__dirname, '../package.json'))
const version = pkg.version
const tag = `explo-code-v${version}`
const commitMessage = `chore(release): \`explo-code\` v${version} :tada:`

execSync('git add .', { stdio: 'inherit' })
execSync(`git commit -m '${commitMessage}'`, { stdio: 'inherit' })
execSync(`git tag -m ${tag} ${tag}`, { stdio: 'inherit' })

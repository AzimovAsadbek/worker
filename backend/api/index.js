// Vercel Node function: every request is rewritten here (see vercel.json) and handled by NestJS.
const handler = require('../dist/serverless').default;
module.exports = (req, res) => handler(req, res);

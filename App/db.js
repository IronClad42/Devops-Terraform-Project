require('dotenv').config();
const mysql = require("mysql2/promise");
// const util = require("util");

const conn = mysql.createPool({
    connectionLimit: 10,
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    connectTimeout: 60000

});

// const exe = util.promisify(conn.query).bind(conn);

async () => exe(sql , value = []) {
    var [ rows ] = await conn.query(sql , value);
    return rows
}

module.exports = exe;
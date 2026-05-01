require('dotenv').config();
var express = require("express");
var bodyparser = require("body-parser");
var upload = require("express-fileupload");
var session = require("express-session")
var cors = require("cors");
var nodemailer = require("nodemailer
var admin = require("./routes/admin");
var user = require("./routes/user");
var app = express();

app.use(bodyparser.urlencoded({ extended: true }));

app.use(upload());

app.use(express.static("public/"));

app.use(cors());

app.use(express.json());

app.use(session({
    resave: true,
    saveUninitialized: true,
    secret: "NodeJsProject"
}));

app.use("/admin", admin);
app.use("/", user);

var port = process.env.PORT;
app.listen(port, () => {
    console.log(`Node Js Project Running ${port}`)
});

// version: "3.9"

// service:
//  service_che_name_aahe_nodejs_mysql:
//   image_che_name_aahe_mysql: "mysql"
//   mysql_che_prot_aahe: "3306"
//   enviroment:
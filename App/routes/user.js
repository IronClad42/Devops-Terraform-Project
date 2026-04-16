require('dotenv').config();
var express = require("express");
var exe = require("../db");
var routes = express.Router();

routes.get("/",async function(req,res){

    var data = await exe(`SELECT * FROM adminside`);
    res.render("user/home.ejs",{info:data});
});

module.exports = routes;

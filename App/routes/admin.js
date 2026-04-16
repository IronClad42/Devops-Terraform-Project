var express = require("express");
var routes = express.Router();
var exe = require("../db");

routes.get("/",async function(req,res){

    var data = await exe(`SELECT * FROM adminside`);

    res.render("admin/home.ejs",{"info":data});
});

routes.post("/submit",async function(req,res){

    var b = req.body;

    var admin_image = "";

        if(req.files && req.files.admin_image)
        {
            admin_image = new Date().getTime()+req.files.admin_image.name;
            req.files.admin_image.mv("public/"+admin_image);
        }

    var sql = `INSERT INTO adminside(admin_name , phone_number , admin_email , admin_image)VALUES
                                    (? , ? , ? , ?)`;

    var data = await exe(sql,[b.admin_name , b.phone_number , b.admin_email , admin_image]);

    res.redirect("/admin");
});

routes.get("/admin_edit/:adminside_id",async function(req,res){
   
    
    
    var data = await exe(`SELECT * FROM adminside WHERE adminside_id = ?`,[req.params.adminside_id]);

    res.render("admin/admin_edit.ejs",{info:data[0]});
});

routes.post("/admin_edit/:admin_edit",async function(req,res){
    
    var b = req.body;
  
    var admin_image  = "";
    if(req.files && req.files.admin_image)
    {
        admin_image = new Date().getTime()+req.files.admin_image.name;
        req.files.admin_image.mv("public/"+admin_image);

        await exe(`UPDATE adminside SET admin_image = ? WHERE adminside_id = ?`,[admin_image , req.params.admin_edit]);
    }

    
     var data = await exe(`UPDATE adminside SET
                           admin_name = ?, 
                           phone_number = ?, 
                           admin_email = ? 
                           WHERE adminside_id = ?
                        `,[b.admin_name , b.phone_number , b.admin_email , req.params.admin_edit]);

    res.redirect("/admin");    
});

routes.get("/admin_delete/:adminside_id",async function(req,res){

    var data = await exe(`DELETE  FROM adminside WHERE adminside_id = ?`,[req.params.adminside_id]);

    res.redirect("/admin");
})
module.exports = routes;

// CREATE TABLE adminside(adminside_id INT PRIMARY KEY AUTO_INCREMENT,
//  admin_name VARCHAR(100),
//  phone_number VARCHAR(100),
//  admin_email VARCHAR(100),
//  admin_image TEXT,
// )


// CREATE TABLE adminside(
//   adminside_id INT PRIMARY KEY AUTO_INCREMENT,
//   admin_name VARCHAR(100),
//   phone_number VARCHAR(100),
//   admin_email VARCHAR(100),
//   admin_image TEXT
// );
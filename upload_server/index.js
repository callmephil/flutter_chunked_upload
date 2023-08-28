// const express = require("express");
// const multer = require("multer");
// const fs = require("fs");
// const cors = require("cors");
// // const { publicIp, publicIpv4, publicIpv6 } = require("public-ip");

import express from "express";
import multer from "multer";
import fs from "fs";
import cors from "cors";
import { publicIp, publicIpv4, publicIpv6 } from "public-ip";

const app = express();

const corsOptions = {
  origin: "*", // You may need to restrict this to specific origins in production
  methods: "GET,HEAD,PUT,PATCH,POST,DELETE",
  allowedHeaders: "Content-Type,Authorization",
};

app.use(cors(corsOptions));
app.use(express.json());
const upload = multer({ dest: "uploads/" });

app.get("/ip", async (req, res) => {
  const ip = await publicIpv4();
  res.status(200).send(ip);
});

app.post("/upload", upload.single("chunk"), (req, res) => {
  const { fileName, chunkIndex } = req.body;
  if (!fileName || !chunkIndex) {
    return res.status(400).send("Missing required parameters");
  }
  if (!req.file) {
    return res.status(400).send("Missing required file");
  }

  const chunkPath = req.file.path;
  const newPath = `./uploads/${fileName}_chunk${chunkIndex}`;

  fs.rename(chunkPath, newPath, (err) => {
    if (err) {
      res.status(500).send("Internal server error");
    } else {
      const delay = 1000; // delay in milliseconds
      setTimeout(() => {
        // res.status(200).send("Uploaded chunk with delay");
        res.status(200).send(`Uploaded chunk ${chunkIndex}`);
      }, delay);
    }
  });
});

app.post("/finalize-upload", (req, res) => {
  const { fileName, totalChunks } = req.body;
  // Combine all the chunks into the final file
  const finalFilePath = `./uploads/${fileName}`;
  const writeStream = fs.createWriteStream(finalFilePath);
  let currentChunk = 0;
  function appendNextChunk() {
    if (currentChunk < totalChunks) {
      const chunkFilePath = `./uploads/${fileName}_chunk${currentChunk}`;
      const readStream = fs.createReadStream(chunkFilePath);
      readStream.pipe(writeStream, { end: false });
      readStream.on("end", () => {
        fs.unlink(chunkFilePath, (err) => {
          if (err) {
            console.error(`Error deleting chunk file: ${chunkFilePath}`);
          }
        });
        currentChunk++;
        appendNextChunk();
      });
    } else {
      writeStream.end();
      res.status(200).send("File upload complete");
    }
  }
  appendNextChunk();
});

app.post("/cancel-upload", (req, res) => {
  // canceling upload will verify if there are remaining chunks and delete them.

  const { fileName } = req.body;
  console.log("canceling on: ", fileName);
  // Combine all the chunks into the final file
  fs.readdir("./uploads", (err, files) => {
    if (err) {
      console.error(`Error reading directory: ${err}`);
    } else {
      files.forEach((file) => {
        if (file.includes(fileName) && file.includes("chunk")) {
          fs.unlink(`./uploads/${file}`, (err) => {
            if (err) {
              console.error(`Error deleting chunk file: ${file}`);
            }
          });
        }
      });
      res.status(200).send("File upload canceled");
    }
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server listening on port ${PORT}`));

package data

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
)

// Document structure
type Document struct {
	Data64 string
	Hash   string
}

var data = []byte("data1234")
var data64 = base64.StdEncoding.EncodeToString(data)
var tmp = sha256.Sum256([]byte(data64))

// ExampleDocument : a test document:
var ExampleDocument = Document{
	Data64: data64,
	Hash:   hex.EncodeToString(tmp[:]),
}

package rest

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"strconv"
	"time"

	"github.com/labstack/echo/v4"
	log "github.com/sirupsen/logrus"
)

var dummyDB = make(map[string]string)

func storeData(c echo.Context) error {
	body, _ := ioutil.ReadAll(c.Request().Body)
	log.Infof("on %s got: %s", c.Echo().Server.Addr, string(body))

	// extract hash
	id := c.Param("id")
	if len(id) != 64 {
		return c.String(http.StatusInternalServerError, `{ "error": "invalid id parameter. length mismatch `+string(len(id))+`" }`)
	}

	//store data
	log.Infof("DB[%s] = %s", id, string(body))
	dummyDB[id] = string(body)

	// calc hash for return value
	var document map[string]interface{}
	json.Unmarshal(body, &document)
	data := document["data"].(string)
	hash := sha256.Sum256([]byte(data))
	hashs := hex.EncodeToString(hash[:])

	// return the hash in the same way as the offchain-db-adapter
	return c.String(http.StatusOK, hashs)
}

func fetchDocument(c echo.Context) error {
	// extract id
	id := c.Param("id")
	if len(id) != 64 {
		return c.String(http.StatusInternalServerError, `{ "error": "invalid id parameter. length mismatch `+string(len(id))+`" }`)
	}

	// access dummy db
	val, knownHash := dummyDB[id]
	if !knownHash {
		log.Errorf("could not find id " + id + " in db")
		return c.String(http.StatusInternalServerError, "id not found")
	}

	// return the data
	return c.String(http.StatusOK, val)
}

func fetchDocuments(c echo.Context) error {
	var documents map[string]map[string]interface{}
	documents = make(map[string]map[string]interface{})

	for id, data := range dummyDB {
		var document map[string]interface{}
		json.Unmarshal([]byte(data), &document)

		documents[id] = document
	}

	val, err := json.Marshal(documents)

	if err != nil {
		return c.String(http.StatusInternalServerError, err.Error())
	}

	// return the data
	return c.String(http.StatusOK, string(val))
}

func fetchDocumentID(c echo.Context) error {
	// extract id
	storageKey := c.Param("storageKey")
	if len(storageKey) != 64 {
		return c.String(http.StatusInternalServerError, `{ "error": "invalid id parameter. length mismatch `+string(len(storageKey))+`" }`)
	}

	// access dummy db
	// loop through all (inefficient but good enough for this test)
	for id, data := range dummyDB {
		var document map[string]interface{}
		json.Unmarshal([]byte(data), &document)

		// calc hash of from storageKey
		tmp := sha256.Sum256([]byte(document["fromMSP"].(string) + id))
		if hex.EncodeToString(tmp[:]) == storageKey {
			return c.String(http.StatusOK, `{ "documentID": "`+id+`" }`)
		}
		// calc hash of to storageKey
		tmp = sha256.Sum256([]byte(document["fromMSP"].(string) + id))
		if hex.EncodeToString(tmp[:]) == storageKey {
			return c.String(http.StatusOK, `{ "documentID": "`+id+`" }`)
		}
	}

	log.Errorf("could not find storageKey " + storageKey + " in db")
	return c.String(http.StatusInternalServerError, "id not found")
}

// StartServer will start a dummy rest server
func StartServer(port int) {
	e := echo.New()

	// define routes
	e.PUT("/documents/:id", storeData)
	e.GET("/documents/:id", fetchDocument)
	e.GET("/documents", fetchDocuments)
	e.GET("/documentIDs/:storageKey", fetchDocumentID)

	// start server
	url := ":" + strconv.Itoa(port)
	log.Info("will listen on " + url)
	go func() {
		err := e.Start(url)
		if err != nil {
			log.Panic(err)
		}
	}()
	time.Sleep(200 * time.Millisecond)
}

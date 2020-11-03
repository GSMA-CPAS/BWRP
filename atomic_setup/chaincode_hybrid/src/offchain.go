/*
	Chaincode POC
	- hybrid approach
	- offchain data storage (REST interface)
	- hidden communication on chain (only partners can derive storage location)
	- hlf composite keys for storage

	See offchain_test.go for an example workflow with mocked rest interface.

	A short note on the composite key feature
	 * for documentation see https://github.com/hyperledger/fabric-chaincode-go/blob/master/shim/interfaces.go
	 * example:
	   - let objectType = "owner~type~key~txid"
	   - key = CreateCompositeKey(objectType, []string{ "ORG1", "SIGNATURE", "12345", "user1"})
	   - the resulting key result will be "\x00owner~type~key~txid\x00ORG1\x00SIGNATURE\x0012345\x00abcdef\x00"


	documentation links:
	- https://github.com/hyperledger/fabric-contract-api-go/blob/master/tutorials/getting-started.md
	- https://github.com/hyperledger/fabric-contract-api-go/blob/master/tutorials/using-advanced-features.md
*/

package main

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	log "github.com/sirupsen/logrus"
)

const compositeKeyDefinition string = "owner~type~key~txid"

// RESTDocument struct as passed to the rest interface
type RESTDocument struct {
	FromMSP   string `json:"fromMSP"`
	ToMSP     string `json:"toMSP"`
	Data      string `json:"data"`
	DataHash  string `json:"dataHash"`
	TimeStamp string `json:"timeStamp"`
	ID        string `json:"id"`
}

func main() {
	// set loglevel
	log.SetLevel(log.DebugLevel)

	// instantiate chaincode
	roamingChaincode := new(RoamingSmartContract)
	chaincode, err := contractapi.NewChaincode(roamingChaincode)
	if err != nil {
		log.Panicf("failed to create chaincode: %s", err.Error())
		return
	}

	// run chaincode
	err = chaincode.Start()
	if err != nil {
		log.Panicf("failed to start chaincode: %s", err.Error())
	}
}

// RoamingSmartContract creates a new hlf contract api
type RoamingSmartContract struct {
	contractapi.Contract
}

// GetRESTConfig returns the stored configuration for the rest endpoint
// ACL restricted to local queries only
func (s *RoamingSmartContract) GetRESTConfig(ctx contractapi.TransactionContextInterface) (string, error) {
	// get caller msp
	invokingMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return "", err
	}
	// verify that this is a local call
	if invokingMSPID != os.Getenv("CORE_PEER_LOCALMSPID") {
		log.Errorf("ACCESS VIOLATION by %s. Only local calls are allowed", invokingMSPID)
		return "", fmt.Errorf("access denied")
	}
	config, err := s.getLocalRESTConfig(ctx)

	return config, err
}

// getRESTConfig returns the stored configuration for the rest endpoint
// this is only allowed to be called locally
// NOTE: (1) DO NOT expose this as it might leak sensitive network configuration use GetRESTConfig for this.
//       (2) always use the LOCALMSPID implicit collection here as we need the configuration of _this_ peer
func (s *RoamingSmartContract) getLocalRESTConfig(ctx contractapi.TransactionContextInterface) (string, error) {
	// the getter will always use the local collection where this chaincode runs
	implicitCollection := "_implicit_org_" + os.Getenv("CORE_PEER_LOCALMSPID")

	// fetch data from implicit collection
	data, err := ctx.GetStub().GetPrivateData(implicitCollection, "REST_URI")
	if err != nil {
		return "", err
	}
	if data == nil {
		return "", fmt.Errorf("REST configuration not set. Please configure it by calling setRESTConfig()")
	}

	// return result
	return string(data), nil
}

// SetRESTConfig stores the rest endpoint config
func (s *RoamingSmartContract) SetRESTConfig(ctx contractapi.TransactionContextInterface) error {
	// get caller msp
	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return err
	}

	// the setter will always set the collection that he owns!
	implicitCollection := "_implicit_org_" + mspID

	// uri is stored in transient map to hide it from other organizations
	transMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("Error getting transient: " + err.Error())
	}

	// fetch transient data
	uri, ok := transMap["uri"]
	if !ok {
		return fmt.Errorf("uri not found in the transient map")
	}

	// store data in implicit collection
	return ctx.GetStub().PutPrivateData(implicitCollection, "REST_URI", uri)
}

// GetEvaluateTransactions returns functions of RoamingSmartContract to be tagged as evaluate (=query)
// see https://godoc.org/github.com/hyperledger/fabric-contract-api-go/contractapi#SystemContract.GetEvaluateTransactions
// note: this is just a hint for the caller, this is not taken into account during invocation
func (s *RoamingSmartContract) GetEvaluateTransactions() []string {
	return []string{"GetRESTConfig", "CreateDocumentID", "CreateStorageKey", "GetSignatures", "GetStorageLocation", "StoreDocumentHash", "StorePrivateDocument", "FetchPrivateDocument", "FetchPrivateDocuments"}
}

// CreateDocumentID creates a DocumentID and verifies that is has not been used yet
func (s *RoamingSmartContract) CreateDocumentID(ctx contractapi.TransactionContextInterface) (string, error) {
	// TODO: verify that the golang crypto lib returns random numbers that are good enough to be used here!
	rand32 := make([]byte, 32)
	_, err := rand.Read(rand32)
	if err != nil {
		log.Errorf("failed to generate documentID: %s", err.Error())
		return "", err
	}

	// encode random numbers to hex string
	documentID := hex.EncodeToString(rand32)

	// get the calling MSP
	invokingMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		log.Errorf("failed to fetch calling MSPID: %s", err.Error())
		return "", err
	}

	// make sure that there is no such document id for this MSP on the ledger yet:
	storageKey, err := s.CreateStorageKey(invokingMSPID, documentID)
	data, err := ctx.GetStub().GetState(storageKey)
	if err != nil {
		log.Errorf("failed to get ledger state: %s", err.Error())
		return "", err
	}

	if data != nil {
		log.Errorf("data for this documentID already exists.")
		return "", fmt.Errorf("data for this documentID already exists")
	}

	// fine, data does not exist on ledger -> the calulated documentID is ok
	return documentID, nil
}

// CreateStorageKey returns the hidden key used for hidden communication based on a documentID and the targetMSP
func (s *RoamingSmartContract) CreateStorageKey(targetMSPID string, documentID string) (string, error) {
	if len(documentID) != 64 {
		return "", fmt.Errorf("invalid input: size of documentID is invalid: %d != 64", len(documentID))
	}
	if len(targetMSPID) == 0 {
		return "", fmt.Errorf("invalid input: targetMSPID is empty")
	}
	hash := sha256.Sum256([]byte(targetMSPID + documentID))
	return hex.EncodeToString(hash[:]), nil
}

// GetSignatures returns all signatures stored in the ledger for this key
func (s *RoamingSmartContract) GetSignatures(ctx contractapi.TransactionContextInterface, targetMSPID string, key string) (map[string]string, error) {
	// query results for composite key without identity
	iterator, err := ctx.GetStub().GetStateByPartialCompositeKey(compositeKeyDefinition, []string{targetMSPID, "SIGNATURE", key})

	if err != nil {
		log.Errorf("failed to query results for partial composite key: %s", err.Error())
		return nil, err
	}

	if iterator == nil {
		log.Infof("no results found")
		return nil, fmt.Errorf("GetSignatures found no results")
	}

	results := make(map[string]string, 0)

	for iterator.HasNext() {
		item, err := iterator.Next()

		if err != nil {
			log.Errorf("failed to iterate results: %s", err.Error())
			return nil, err
		}

		_, attributes, err := ctx.GetStub().SplitCompositeKey(item.GetKey())

		if err != nil {
			log.Errorf("failed to split composite result: %s", err.Error())
			return nil, err
		}

		txID := attributes[len(attributes)-1]
		log.Infof("state[%s] txID %s = %s", item.GetKey(), txID, item.GetValue())
		results[txID] = string(item.GetValue())
	}

	return results, nil
}

// GetStorageLocation returns the storage location for
// a given storageType and key by using the composite key feature
func (s *RoamingSmartContract) GetStorageLocation(ctx contractapi.TransactionContextInterface, storageType string, key string) (string, error) {
	// get the calling MSP
	invokingMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		log.Errorf("failed to fetch calling MSPID: %s", err.Error())
		return "", err
	}

	// get the txID
	txID := ctx.GetStub().GetTxID()

	// construct the storage location
	storageLocation, err := ctx.GetStub().CreateCompositeKey(compositeKeyDefinition, []string{invokingMSPID, storageType, key, txID})

	if err != nil {
		log.Errorf("failed to create composite key: %s", err.Error())
		return "", err
	}

	log.Infof("got composite key for <%s> = 0x%s", compositeKeyDefinition, hex.EncodeToString([]byte(storageLocation)))

	return storageLocation, nil
}

// storeData stores given data with a given type on the ledger
func (s *RoamingSmartContract) storeData(ctx contractapi.TransactionContextInterface, key string, dataType string, data []byte) error {
	// get the calling MSP
	invokingMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		log.Errorf("failed to fetch calling MSPID: %s", err.Error())
		return err
	}

	// fetch storage location where we will store the data
	storageLocation, err := s.GetStorageLocation(ctx, dataType, key)
	if err != nil {
		log.Errorf("failed to fetch storageLocation: %s", err.Error())
		return err
	}

	// store data
	log.Infof("will store data of type %s on ledger: state[%s] = 0x%s", dataType, storageLocation, hex.EncodeToString(data))
	err = ctx.GetStub().PutState(storageLocation, data)
	if err != nil {
		log.Errorf("failed to store data: %s", err.Error())
		return err
	}

	// fetch tx creation time
	txTimestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		log.Errorf("failed to fetch tx creation timestamp: %s", err.Error())
		return err
	}

	// build event object
	eventName := "STORE:" + dataType
	timestampString := time.Unix(txTimestamp.Seconds, int64(txTimestamp.Nanos)).Format(time.RFC3339)

	payload := `{ ` +
		`"msp" : "` + invokingMSPID + `", ` +
		`"eventName" : "` + eventName + `", ` +
		`"timestamp" : "` + timestampString + `", ` +
		`"data" : { "storageKey" : "` + key + `" }` +
		` }`

	log.Infof("sending event %s: %s", eventName, payload)
	err = ctx.GetStub().SetEvent(eventName, []byte(payload))
	if err != nil {
		log.Errorf("failed to set event: %s", err.Error())
		return err
	}

	// no error
	return nil
}

// StoreSignature stores a given signature on the ledger
func (s *RoamingSmartContract) StoreSignature(ctx contractapi.TransactionContextInterface, key string, signatureJSON string) error {
	return s.storeData(ctx, key, "SIGNATURE", []byte(signatureJSON))
}

// StoreDocumentHash stores a given document hash on the ledger
func (s *RoamingSmartContract) StoreDocumentHash(ctx contractapi.TransactionContextInterface, key string, documentHash string) error {
	return s.storeData(ctx, key, "DOCUMENTHASH", []byte(documentHash))
}

// StorePrivateDocument will store contract Data locally
// this can be called on a remote peer or locally
// payload is a DataPayload object that contains a nonce and the payload
func (s *RoamingSmartContract) StorePrivateDocument(ctx contractapi.TransactionContextInterface, targetMSPID string, documentID string, documentBase64 string) (string, error) {
	// verify passed data
	if len(documentID) != 64 {
		return "", fmt.Errorf("invalid input: size of documentID is invalid: %d != 64", len(documentID))
	}

	// get the calling MSP
	invokingMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		log.Errorf("failed to fetch MSPID: %s", err.Error())
		return "", err
	}

	// only allow target override if called locally
	localMSPID := os.Getenv("CORE_PEER_LOCALMSPID")
	if invokingMSPID != localMSPID {
		// called from a external MSP
		if targetMSPID != localMSPID {
			// external MSP wants to set an invalid targetMSP
			return "", fmt.Errorf("forbidden: invalid targetMSPID. only local overrides are allowed")
		}
	}

	// calc hash over the data
	sha256 := sha256.Sum256([]byte(documentBase64))
	dataHash := hex.EncodeToString(sha256[:])

	// create rest struct
	var document RESTDocument
	document.ID = documentID
	document.TimeStamp = strconv.FormatInt(time.Now().UnixNano(), 10)
	document.Data = documentBase64
	document.DataHash = dataHash
	document.FromMSP = invokingMSPID
	document.ToMSP = targetMSPID
	documentJSON, err := json.Marshal(document)

	if err != nil {
		log.Errorf("failed to marshal json")
		return "", err
	}

	// fetch the configured rest endpoint
	baseURL, err := s.getLocalRESTConfig(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to fetch REST uri: %s", err.Error())
	}

	// offchain-db-adapter target url
	url := baseURL + "/documents/" + documentID
	log.Infof("will send PUT request to %s", url)

	client := &http.Client{}
	req, err := http.NewRequest(http.MethodPut, url, bytes.NewBuffer(documentJSON))
	if err != nil {
		log.Errorf("REST request failed to create request. Error: %s", err.Error())
		return "", err
	}

	// set the request header Content-Type for json
	req.Header.Set("Content-Type", "application/json")
	response, err := client.Do(req)

	if err != nil {
		log.Errorf("REST request failed. Error: %s", err.Error())
		return "", err
	}

	log.Infof("got response status %s", response.Status)
	if response.StatusCode != 200 {
		log.Errorf("REST request on %s failed. Status: %s", url, response.Status)
		return "", fmt.Errorf("REST request on %s failed. Status: %s", url, response.Status)
	}

	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Errorf("failed to decode body (status = %s, header = %s)", response.Status, response.Header)
		return "", err
	}

	// fetch returned hash of the data
	storedDataHash := string(body)
	log.Infof("got response body, stored data hash %s", storedDataHash)

	// verify that the hash from the post request matches our data
	if dataHash != storedDataHash {
		log.Errorf("hash mismatch %s != %s", dataHash, storedDataHash)
		return "", fmt.Errorf("error, hash mismatch")
	}

	return storedDataHash, nil
}

// FetchPrivateDocument will return a private document identified by its documentID
// ACL restricted to local queries only
func (s *RoamingSmartContract) FetchPrivateDocument(ctx contractapi.TransactionContextInterface, documentID string) (string, error) {
	log.Infof("fetching document with id " + documentID)
	return s.privateDocumentsAccess(ctx, "/documents/"+documentID)
}

// FetchPrivateDocuments will return a list of the last n private documents
// for now n=100, see offchain db adapter
// ACL restricted to local queries only
func (s *RoamingSmartContract) FetchPrivateDocuments(ctx contractapi.TransactionContextInterface) (string, error) {
	return s.privateDocumentsAccess(ctx, "/documents")
}

func (s *RoamingSmartContract) privateDocumentsAccess(ctx contractapi.TransactionContextInterface, path string) (string, error) {
	// get the calling MSP
	invokingMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		log.Errorf("failed to fetch MSPID: %s", err.Error())
		return "", err
	}

	log.Infof(invokingMSPID + " accessing private documents via path " + path)

	// verify that this is a local call
	if invokingMSPID != os.Getenv("CORE_PEER_LOCALMSPID") {
		log.Errorf("ACCESS VIOLATION by %s. Only local calls are allowed", invokingMSPID)
		return "", fmt.Errorf("access denied")
	}

	// fetch the configured rest endpoint
	baseURL, err := s.getLocalRESTConfig(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to fetch REST uri: %s", err.Error())
	}

	// offchain-db-adapter target url
	url := baseURL + path
	log.Infof("will send GET request to %s", url)

	response, err := http.Get(url)

	if err != nil {
		log.Errorf("REST request failed. Error: %s", err.Error())
		return "", err
	}

	log.Infof("got response status %s", response.Status)
	if response.StatusCode != 200 {
		log.Errorf("REST request on %s failed. Status: %s, Body = %s", url, response.Status, response.Body)
		// NOTE: returning detailled error messages here is safe as this function
		//       is only called locally (see check above). DO NOT expose sensitive information in other calls.
		return "", fmt.Errorf("REST request on %s failed: Status = %s, Body = %s", url, response.Status, response.Body)
	}

	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Errorf("failed to decode body (status = %s, header = %s)", response.Status, response.Header)
		return "", err
	}

	// return result
	return string(body), nil
}

// GetDocumentID will return a private documentID based on a storageKey
// This only works for documentIDs known to this MSP
// ACL restricted to local queries only
func (s *RoamingSmartContract) GetDocumentID(ctx contractapi.TransactionContextInterface, storageKey string) (string, error) {
	log.Infof("fetching documentID for storageKey " + storageKey)

	// get the calling MSP
	invokingMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		log.Errorf("failed to fetch MSPID: %s", err.Error())
		return "", err
	}

	// verify that this is a local call
	if invokingMSPID != os.Getenv("CORE_PEER_LOCALMSPID") {
		log.Errorf("ACCESS VIOLATION by %s. Only local calls are allowed", invokingMSPID)
		return "", fmt.Errorf("access denied")
	}

	// fetch the configured rest endpoint
	baseURL, err := s.getLocalRESTConfig(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to fetch REST uri: %s", err.Error())
	}

	// offchain-db-adapter target url
	url := baseURL + "/documentIDs/" + storageKey
	log.Infof("will send GET request to %s", url)

	response, err := http.Get(url)

	if err != nil {
		log.Errorf("REST request failed. Error: %s", err.Error())
		return "", err
	}

	log.Infof("got response status %s", response.Status)
	if response.StatusCode != 200 {
		log.Errorf("REST request on %s failed. Status: %s, Body = %s", url, response.Status, response.Body)
		// NOTE: returning detailled error messages here is safe as this function
		//       is only called locally (see check above). DO NOT expose sensitive information in other calls.
		return "", fmt.Errorf("REST request on %s failed: Status = %s, Body = %s", url, response.Status, response.Body)
	}

	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Errorf("failed to decode body (status = %s, header = %s)", response.Status, response.Header)
		return "", err
	}

	// return result
	return string(body), nil
}

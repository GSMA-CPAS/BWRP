package main

//see https://github.com/hyperledger/fabric-samples/blob/master/asset-transfer-basic/chaincode-go/chaincode/smartcontract_test.go

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"hybrid/test/chaincode"
	. "hybrid/test/data"
	"hybrid/test/historyshimtest"
	"hybrid/test/mocks"
	"hybrid/test/rest"
	"os"
	"strconv"
	"testing"

	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"
	"github.com/stretchr/testify/require"
)

type EndpointMap map[*Organization]Endpoint

type Endpoint struct {
	org       *Organization
	contract  *RoamingSmartContract
	txContext *mocks.TransactionContext
	stub      *historyshimtest.MockStub
}

func createEndpoints(t *testing.T) (Endpoint, Endpoint) {
	// set loglevel
	log.SetLevel(log.InfoLevel)

	// set up stub
	mockStub := historyshimtest.NewMockStub("roamingState", nil)

	epORG1 := configureEndpoint(t, mockStub, ORG1)
	epORG2 := configureEndpoint(t, mockStub, ORG2)

	return epORG1, epORG2
}

func configureEndpoint(t *testing.T, mockStub *historyshimtest.MockStub, org Organization) Endpoint {
	var ep Endpoint
	ep.org = &org
	log.Infof(ep.org.Name + ": configuring rest endpoint")

	// store mockstub
	ep.stub = mockStub

	// set up local msp id
	os.Setenv("CORE_PEER_LOCALMSPID", ep.org.Name)

	//start a simple rest servers to handle requests from chaincode
	rest.StartServer(ep.org.RestConfigPort)

	// init contract
	ep.contract = &RoamingSmartContract{}

	// tx context
	txContext, err := chaincode.PrepareTransactionContext(ep.stub, ep.org.Name, ep.org.Certificate)
	require.NoError(t, err)

	// use context
	ep.txContext = txContext

	// set transient data for setting rest config
	var transient map[string][]byte
	transient = make(map[string][]byte)
	targetURI := "http://localhost:" + strconv.Itoa(ep.org.RestConfigPort)
	transient["uri"] = []byte(targetURI)
	mockStub.TransientMap = transient
	err = ep.contract.SetRESTConfig(ep.txContext)
	require.NoError(t, err)

	// read back for debugging and testing
	uri, err := ep.contract.GetRESTConfig(ep.txContext)
	log.Infof(ep.org.Name+": read back uri <%s>\n", uri)
	require.NoError(t, err)
	require.EqualValues(t, uri, targetURI)

	return ep
}

// add forwarding functions
// those will make sure that the LOCALMSPID is always equal to the local organization
// and will additionally allow the calls to be executed in the caller's context
func (local Endpoint) storePrivateDocument(caller Endpoint, targetMSPID string, documentID string, documentBase64 string) (string, error) {
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	return local.contract.StorePrivateDocument(caller.txContext, targetMSPID, documentID, documentBase64)
}

func (local Endpoint) fetchPrivateDocument(caller Endpoint, documentID string) (string, error) {
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	return local.contract.FetchPrivateDocument(caller.txContext, documentID)
}

func (local Endpoint) fetchPrivateDocuments(caller Endpoint) (string, error) {
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	return local.contract.FetchPrivateDocuments(caller.txContext)
}

func (local Endpoint) createStorageKey(caller Endpoint, targetMSPID string, documentID string) (string, error) {
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	return local.contract.CreateStorageKey(targetMSPID, documentID) // TODO: no tx context in this func?!
}

func (local Endpoint) getDocumentID(caller Endpoint, storageKey string) (string, error) {
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	return local.contract.GetDocumentID(caller.txContext, storageKey)
}

func (local Endpoint) getRESTConfig(caller Endpoint) (string, error) {
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	return local.contract.GetRESTConfig(caller.txContext)
}

func (local Endpoint) createDocumentID(caller Endpoint) (string, error) {
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	return local.contract.CreateDocumentID(caller.txContext)
}

func (local Endpoint) getSignatures(caller Endpoint, targetMSPID string, key string) (map[string]string, error) {
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	return local.contract.GetSignatures(caller.txContext, targetMSPID, key)
}

func (local Endpoint) invokeStoreDocumentHash(caller Endpoint, key string, documentHash string) error {
	txid := local.org.Name + ":" + uuid.New().String()
	local.stub.MockTransactionStart(txid)
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	err := local.contract.StoreDocumentHash(caller.txContext, key, documentHash)
	local.stub.MockTransactionEnd(txid)
	return err
}

func (local Endpoint) invokeStoreSignature(caller Endpoint, key string, signatureJSON string) error {
	txid := local.org.Name + ":" + uuid.New().String()
	local.stub.MockTransactionStart(txid)
	os.Setenv("CORE_PEER_LOCALMSPID", local.org.Name)
	err := local.contract.StoreSignature(caller.txContext, key, signatureJSON)
	local.stub.MockTransactionEnd(txid)
	return err
}

func TestPrivateDocumentAccess(t *testing.T) {
	// set up proper endpoints
	ep1, ep2 := createEndpoints(t)

	// read private documents on ORG1 with ORG1 tx context
	response, err := ep1.fetchPrivateDocuments(ep1)
	require.NoError(t, err)
	log.Info(response)

	// read private documents on ORG1 with ORG2 tx context
	response, err = ep1.fetchPrivateDocuments(ep2)
	require.Error(t, err)
	log.Info(response)
}

func TestRestConfig(t *testing.T) {
	log.Infof("testing REST")
	// set up proper endpoints
	ep1, ep2 := createEndpoints(t)

	// read back for debugging
	// note that this is not allowed on chaincode calls
	// as getRESTConfig is not exported
	os.Setenv("CORE_PEER_LOCALMSPID", ORG1.Name)
	uri, err := ep1.getRESTConfig(ep1)
	require.NoError(t, err)
	log.Infof("read back uri <%s>\n", uri)

	// read back with txcontext ORG2 -> this has to fail!
	_, err = ep1.getRESTConfig(ep2)
	require.Error(t, err)
}

func TestExchangeAndSigning(t *testing.T) {
	// set up proper endpoints
	ep1, ep2 := createEndpoints(t)

	// calc documentID
	documentID, err := ep1.createDocumentID(ep2)
	require.NoError(t, err)
	log.Infof("got docID <%s>\n", documentID)

	// QUERY store document on ORG1 (local)
	hash, err := ep1.storePrivateDocument(ep1, ORG2.Name, documentID, ExampleDocument.Data64)
	require.NoError(t, err)
	require.EqualValues(t, hash, ExampleDocument.Hash)

	// VERIFY that it was written
	data, err := ep1.fetchPrivateDocument(ep1, documentID)
	require.NoError(t, err)

	// TODO: check all attributes...
	var document map[string]interface{}
	json.Unmarshal([]byte(data), &document)
	require.EqualValues(t, document["data"], ExampleDocument.Data64)

	// QUERY store document on ORG2 (remote)
	hash, err = ep2.storePrivateDocument(ep1, ORG2.Name, documentID, ExampleDocument.Data64)
	require.NoError(t, err)
	require.EqualValues(t, hash, ExampleDocument.Hash)

	// QUERY create storage key
	storagekeyORG1, err := ep1.createStorageKey(ep1, ORG1.Name, documentID)
	require.NoError(t, err)

	// upload document hash on the ledger
	err = ep1.invokeStoreDocumentHash(ep1, storagekeyORG1, ExampleDocument.Hash)
	require.NoError(t, err)

	// ### org1 signs document:
	// create signature (later provided by external API/client)
	signatureORG1 := `{signer: "User1@ORG1", pem: "-----BEGIN CERTIFICATE--- ...", signature: "0x123..." }`
	// INVOKE storeSignature (here only org1, can also be all endorsers)
	err = ep1.invokeStoreSignature(ep1, storagekeyORG1, signatureORG1)
	require.NoError(t, err)

	// ### org2 signs document:
	// QUERY create storage key
	storagekeyORG2, err := ep2.createStorageKey(ep2, ORG2.Name, documentID)
	require.NoError(t, err)
	// create signature (later provided by external API/client)
	signatureORG2 := `{signer: "User1@ORG2", pem: "-----BEGIN CERTIFICATE--- ...", signature: "0x456..." }`

	// INVOKE storeSignature (here only org1, can also be all endorsers)
	err = ep1.invokeStoreSignature(ep2, storagekeyORG2, signatureORG2)
	require.NoError(t, err)

	// ### (optional) org1 checks signatures of org2 on document:
	// QUERY create expected key
	storagekeypartnerORG2, err := ep1.createStorageKey(ep1, ORG2.Name, documentID)
	require.Equal(t, storagekeyORG2, storagekeypartnerORG2)
	require.NoError(t, err)
	// QUERY GetSignatures
	signatures, err := ep1.getSignatures(ep1, ORG2.Name, storagekeypartnerORG2)
	require.NoError(t, err)
	chaincode.PrintSignatureResponse(signatures)

	// ### (optional) org2 checks signatures of org1 on document:
	// QUERY create expected key
	storagekeypartnerORG1, err := ep2.createStorageKey(ep2, ORG1.Name, documentID)
	require.NoError(t, err)
	// QUERY GetSignatures
	signatures, err = ep2.getSignatures(ep2, ORG1.Name, storagekeypartnerORG1)
	require.NoError(t, err)
	chaincode.PrintSignatureResponse(signatures)
}

// Test GetDocumentID storagekeyORG1
func TestGetDocumentID(t *testing.T) {
	// set up proper endpoints
	ep1, ep2 := createEndpoints(t)

	// ### Org1 creates a document and sends it to Org2:
	// a test document:
	documentBase64 := base64.StdEncoding.EncodeToString([]byte(`data!1234...`))

	// calc data hash
	tmp := sha256.Sum256([]byte(documentBase64))
	dataHash := hex.EncodeToString(tmp[:])

	// calc documentID
	documentID, err := ep1.createDocumentID(ep1)
	require.NoError(t, err)
	log.Infof("got docID <%s>\n", documentID)

	// QUERY store document on ORG1 (local)
	hash, err := ep1.storePrivateDocument(ep1, ORG2.Name, documentID, documentBase64)
	require.NoError(t, err)
	require.EqualValues(t, hash, dataHash)

	// QUERY create storage key
	storagekeyORG1, err := ep1.createStorageKey(ep1, ORG1.Name, documentID)
	require.NoError(t, err)

	// ### (optional) org2 checks signatures of org1 on document:
	// QUERY create expected key
	response, err := ep2.getDocumentID(ep2, storagekeyORG1)
	require.NoError(t, err)
	var responseJSON map[string]interface{}
	log.Infof(response)
	err = json.Unmarshal([]byte(response), &responseJSON)
	require.NoError(t, err)
	require.EqualValues(t, responseJSON["documentID"].(string), documentID)

}

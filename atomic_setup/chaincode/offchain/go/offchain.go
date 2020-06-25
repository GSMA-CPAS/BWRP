/*
 */

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
        "github.com/hyperledger/fabric-chaincode-go/pkg/cid"
        "github.com/leesper/couchdb-golang"
        "crypto/hmac"
        "crypto/sha256"
        "encoding/base64"
        "time"
)

type SmartContract struct {
	contractapi.Contract
}

type StatusResponse struct {
        Status    string `json:"status"`
        Info    string `json:"info"`
}

var myDB, _ = couchdb.NewServer("")

// InitLedger not used. Just a place holder
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
        fmt.Println(">InitLedger")
	return nil
}

// Some Test function to make sure Chaincode is responding.
// To be removed in production
func (s *SmartContract) Test(ctx contractapi.TransactionContextInterface) (StatusResponse, error) {
        fmt.Println(">Test")
        fmt.Println("testing")

        cid, err := cid.New(ctx.GetStub())
        if err != nil {
                return StatusResponse{ Status: "ERROR" }, err
        }

        fmt.Println("CORE_PEER_LOCALMSPID="+ os.Getenv("CORE_PEER_LOCALMSPID"))
        mspid, err := cid.GetMSPID()
        fmt.Println("Submitter MSPID=" + mspid)

        x509, err := cid.GetX509Certificate()

        fmt.Println(x509.Subject)
        fmt.Println(x509.NotBefore)
        fmt.Println(x509.NotAfter)

        return StatusResponse{ Status: "OK" }, nil
}

//PutState, Create Tranasction "Signature".
//To be invoked Creator locally.
func (s *SmartContract) PutState(ctx contractapi.TransactionContextInterface, key string, value string) (*StatusResponse, error) {
        fmt.Println(">PutState")

        err := ctx.GetStub().PutState(key, []byte(value))
        if err != nil {
                return nil, fmt.Errorf(err.Error())
        }

        response := new(StatusResponse)
        response.Status = "OK"
        response.Info = "State Set"
        return response, nil
}

//OffChain Push of Payload to Destination MSP
//To be invoke remotely from Creator
//ACL Control forbids to be invoked locally.
func (s *SmartContract) PutData(ctx contractapi.TransactionContextInterface, key string, data string) (*StatusResponse, error) {
        fmt.Println(">PutData")

        cid, err := cid.New(ctx.GetStub())
        if err != nil {
                return nil, fmt.Errorf(err.Error())
        }
        mspid, err := cid.GetMSPID()
        if os.Getenv("CORE_PEER_LOCALMSPID") == mspid {
                return nil, fmt.Errorf("You do not have permission to call this function")
        }

        var x map[string]interface{}
        err2 := json.Unmarshal([]byte(data), &x)
        if err2 != nil {
                return nil, fmt.Errorf("Payload not JSON")
        }

        if x["TXH"] == nil {
                return nil, fmt.Errorf("Payload do not contain key 'TXH'")
        }

        history, err := ctx.GetStub().GetHistoryForKey(x["TXH"].(string));
        if err != nil {
                return nil, fmt.Errorf("Hash Signature not found!")
        }

        for history.HasNext() {
                transaction, _ := history.Next()
                if transaction.IsDelete == false {
                        fmt.Println("TransactionID="+transaction.TxId)
                        fmt.Printf("Current Timestamp=%v ,Transaction Timestamp=%v [diff=%v]\n", time.Now().Unix(), transaction.Timestamp.Seconds, (time.Now().Unix() - transaction.Timestamp.Seconds))
                        fmt.Println("Transaction Value="+string(transaction.Value))

                        if ValidMAC(data, transaction.Value, mspid) == true && transaction.TxId == x["TXH"].(string) && (time.Now().Unix() - transaction.Timestamp.Seconds) < 8 {

                                //add code to write data to localDB
                                // key = key
                                // data = data

                                response := new(StatusResponse)
                                response.Status = "OK"
                                response.Info = "Data Created"
                                return response, nil
                        }

                }
        }

        response := new(StatusResponse)
        response.Status = "Error"
        response.Info = "PutData Failed"
        return response, fmt.Errorf("Cannot verify data.")
}

//Local Chaincode Administration.
//Return currently configured "CouchDB" connection URL
//ACL only allowed to be called locally on peer by an adminstrator
func (s *SmartContract) GetDBURL(ctx contractapi.TransactionContextInterface) (*StatusResponse, error) {
        fmt.Println(">GetDBURL")

        err := ACL(ctx)
        if len(err) > 0 {
                return nil, fmt.Errorf(err)
        }

        if len(os.Getenv("DBURL")) == 0 {
                return nil, fmt.Errorf("DBURL not Set")
        } else {
                response := new(StatusResponse)
                response.Status = "OK"
                response.Info = os.Getenv("DBURL")
                return response, nil
        }
}

//Local Chaincode Administration.
//Set or Update "CouchDB" connection URL
//ACL only allowed to be called locally on peer by an adminstrator
func (s *SmartContract) SetDBURL(ctx contractapi.TransactionContextInterface, dbURL string) (*StatusResponse, error) {
        fmt.Println(">SetDBURL")

        err := ACL(ctx)
        if len(err) > 0 {
                return nil, fmt.Errorf(err)
        }

        os.Setenv("DBURL", dbURL)
        response := new(StatusResponse)
        response.Status = "OK"
        response.Info = os.Getenv("DBURL")
        return response, nil
}

//Local Chaincode Administration.
//Get Connected CouchDB Version
//to check that CouchDB connection is working
//ACL only allowed to be called locally on peer by an adminstrator
func (s *SmartContract) GetDBVersion(ctx contractapi.TransactionContextInterface) (*StatusResponse, error) {
        fmt.Println(">GetDBVersion")

        err := ACL(ctx)
        if len(err) > 0 {
                return nil, fmt.Errorf(err)
        }

        err = connectCouchDB()
        if len(err) > 0 {
                return nil, fmt.Errorf(err)
        }

        ver, _ := myDB.Version()
        response := new(StatusResponse)
        response.Status = "OK"
        response.Info = ver
        return response, nil
}

//Local Chaincode Administration.
//Get number of DB of the Connected CouchDB 
//to proof that CouchDB connection is working
//ACL only allowed to be called locally on peer by an adminstrator
func (s *SmartContract) GetDBList(ctx contractapi.TransactionContextInterface) ([]string, error) {
        fmt.Println(">GetDBVersion")

        err := ACL(ctx)
        if len(err) > 0 {
                return nil, fmt.Errorf(err)
        }

        err = connectCouchDB()
        if len(err) > 0 {
                return nil, fmt.Errorf(err)
        }

        dbs, _ := myDB.DBs()
        return dbs, nil
}

//ACL Control
func ACL(ctx contractapi.TransactionContextInterface) (string) {
        fmt.Println(">ACL")
        cid, err := cid.New(ctx.GetStub())
        if err != nil {
                return err.Error()
        }
        mspid, err := cid.GetMSPID()
        if os.Getenv("CORE_PEER_LOCALMSPID") != mspid {
                return "You do not have permission to call this function"
        }

        found, err := cid.HasOUValue("admin")
        if found == false {
                return "You do not have permission to call this function"
        }
        return ""
}

//Connect to CouchDB instance
func connectCouchDB() (string) {
        if len(os.Getenv("DBURL")) == 0 {
                return "DBURL not Set"
        } else {
                dbs, err := myDB.Len()
                if err != nil {
                        fmt.Println(err)
                }
                if dbs == -1 {
                        myDB, err = couchdb.NewServer(os.Getenv("DBURL"))
                        fmt.Println("Initialize Server Instance")
                }
                return ""
        }
}

//Calculate and verify HMAC_SHA256 key, message
func ValidMAC(message string, messageMAC_byte []byte, key string) bool {
        fmt.Println(">ValidMAC")
        key_byte := []byte(key)
        message_byte := []byte(message)

        mac := hmac.New(sha256.New, key_byte)
        mac.Write(message_byte)
        expectedMAC := mac.Sum(nil)
        fmt.Println(">Expected HMAC="+ string(messageMAC_byte) +", Calculated HMAC="+ base64.StdEncoding.EncodeToString(expectedMAC))
        decoded, err := base64.StdEncoding.DecodeString(string(messageMAC_byte))
        if err != nil {
                fmt.Println(err.Error())
                return false
        }

        return hmac.Equal(decoded, expectedMAC)
}


func main() {
	chaincode, err := contractapi.NewChaincode(new(SmartContract))

	if err != nil {
		fmt.Printf("Error create offchain chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting offchain chaincode: %s", err.Error())
	}
}

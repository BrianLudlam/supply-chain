pragma solidity ^0.5.10;

/**
 * @title A Supply Chain prototype contract implementation.
 * @author Brian Ludlam
 * @notice All Supply Chain relevant data is stored on-chain, with all data erroneous 
 * to the system stored on IPFS. All information in the system, whether on-chain or on
 * IPFS, is impossible to change without a contract event logging the change, and all 
 * versions of all data can be permanently referenced on IPFS.
 * A Supply Chain is defined in this system as a Directed Acyclic Graph of supply steps 
 * that follow the production of something back to it's conception. A supply step always 
 * references a single item in the system, and may extend one or more previous supply steps, 
 * or precedents. A new step may only be added as a first step, or the last step of an existing 
 * supply chain. Approval must be granted to create a new supply step, which extends a supply 
 * step not owned directly.
 */
contract SupplyChain {

    /**
     * Struct IPFile - IPFS file signature data structure.
     */
    struct IPFile {
        bytes32 digest;//file digest = file hash
        uint8 meta;//file meta = file hashing algorithm type
        uint8 size;//file size
    }
    
    /**
     * Struct SupplyNode - Supply Node data structure.
     */
    struct SupplyNode {
        address owner;//owner / creator of Supply Node
        IPFile nodeFile;//IPFS File for Supply Node
        uint256 steps;//number of Supply Steps setup on this Supply Node
        mapping(address => bool) operator;//Supply Node Operators
    }
    
    /**
     * Struct SupplyStep - Supply Step data structure.
     */
    struct SupplyStep {
        uint256 node;//Origin Supply Node
        uint256 item;//Referenced Supply Item
        IPFile stepFile;//IPFS File for Supply Step
        uint256[] precedents;//preceding Supply Steps to this Supply Step
        uint256 approvals;//number of Supply Node access approvals for this Supply Step
        mapping(uint256 => bool) approval;//mapping of Supply Node access approvals
    }

    //developer account with primary contract control
    address payable private _developer;

    //Supply Node Index
    uint256 private _nodeIndex;
   
    //Supply Node index mapping to SupplyNode data structure
    mapping(uint256 => SupplyNode) private _supplyNode;
    
    //Supply Item Index
    uint256 _itemIndex;
    
    //Supply Item index mapping to IPFS file data structure
    mapping(uint256 => IPFile) _itemFile;
    
    //Supply Item index mapping to origin Supply Node
    mapping(uint256 => uint256) _itemNode;
    
    //Supply Item index mapping to index of it's last Supply Step (zero if none.)
    mapping(uint256 => uint256) _itemStep;
   
    //Supply Step Index
    uint256 private _stepIndex;
   
    //Supply Step mapping from index to SupplyStep data structure
    mapping(uint256 => SupplyStep) private _supplyStep;

    /**
     * Event SupplyNodeAdded - Log each time a new Supply Node is added.
     * @return nodeId = Supply Node ID
     * @return owner = Supply Node owner
     * @return timestamp = Timestamp when Supply Node was added.
     */
    event SupplyNodeAdded(
        uint256 indexed nodeId, 
        address indexed owner, 
        uint256 timestamp
    );
    
    /**
     * Event SupplyNodeRemoved - Log each time a new Supply Node is removed.
     * @return nodeId = Supply Node ID
     * @return owner = Supply Node owner
     * @return timestamp = Timestamp when Supply Node was removed.
     */
    event SupplyNodeRemoved(
        uint256 indexed nodeId, 
        address indexed owner, 
        uint256 timestamp
    );

    /**
     * Event NodeOpApproval - Log each change in new Supply Node operator approval status.
     * @return nodeId = Supply Node ID
     * @return operator = Supply Node operator
     * @return approved = Supply Node operator approval status
     * @return timestamp = Timestamp of Supply Node operator status change.
     */
    event NodeOpApproval(
        uint256 indexed nodeId,
        address indexed operator,
        bool approved,
        uint256 timestamp
    );

    /**
     * Event SupplyItemAdded - Log each time a new Supply Item is added.
     * @return itemId = Supply Item ID that was added.
     * @return nodeId = Supply Node ID that Supply Item was added to.
     * @return timestamp = Timestamp when Supply Item was added.
     */
    event SupplyItemAdded(
        uint256 indexed itemId, 
        uint256 indexed nodeId, 
        uint256 timestamp
    );
    
    /**
     * Event SupplyItemRemoved - Log each time a new Supply Item is removed.
     * @return itemId = Supply Item ID that was removed.
     * @return nodeId = Supply Node ID that Supply Item was removed from.
     * @return timestamp = Timestamp when Supply Item was removed.
     */
    event SupplyItemRemoved(
        uint256 indexed itemId, 
        uint256 indexed nodeId, 
        uint256 timestamp
    );
    
    /**
     * Event SupplyStepAdded - Log each time a new Supply Step is added.
     * @return stepId = Supply Step ID that was added.
     * @return nodeId = Supply Node ID that Supply Step was added to.
     * @return itemId = Supply Item ID that Supply Step references.
     * @return timestamp = Timestamp when Supply Step was added.
     */
    event SupplyStepAdded(
        uint256 indexed stepId, 
        uint256 indexed nodeId, 
        uint256 indexed itemId,
        uint256 timestamp
    );
    
    /**
     * Event SupplyStepRemoved - Log each time a new Supply Step is removed.
     * @return stepId = Supply Step ID that was added.
     * @return nodeId = Supply Node ID that Supply Step was added to.
     * @return itemId = Supply Item ID that Supply Step references.
     * @return timestamp = Timestamp when Supply Step was removed.
     */
    event SupplyStepRemoved(
        uint256 indexed stepId, 
        uint256 indexed nodeId, 
        uint256 indexed itemId,
        uint256 timestamp
    );

    /**
     * Event SupplyStepRequest - Log Supply Step access requested by Supply Node.
     * @return stepId = Supply Step ID being requested for access.
     * @return owner = Owner of Supply Node requesting access. 
     * @return nodeId = Supply Node ID requesting access.
     * @return timestamp = Timestamp when Supply Step access was requested.
     */
    event SupplyStepRequest(
        uint256 indexed stepId, 
        address indexed owner,
        uint256 indexed nodeId,
        uint256 timestamp
    );

    /**
     * Event SupplyNodeApproval - Log Supply Step access approval status change for Supply Node.
     * @return stepId = Supply Step ID approving access to Supply Node.
     * @return owner = Owner of Supply Node receiving approval for access. 
     * @return nodeId = Supply Node ID receiving approval for access. 
     * @return approved = Supply Node approval status
     * @return timestamp = Timestamp when Supply Node access approval status changed.
     */
    event SupplyNodeApproval(
        uint256 indexed stepId, 
        address indexed owner,
        uint256 indexed nodeId, 
        bool approved,
        uint256 timestamp
    );

    //Contract constructor sets developer account control and initializes indexes.
    constructor() public { 
        _developer = msg.sender;
        _nodeIndex = _stepIndex = _itemIndex = 0;
    }
    
    /**
     * Transaction addSupplyNode - Add Supply Node with IPFS file data.
     * @param fileDigest = IPFS file multihash - hash data part
     * @param fileMeta = IPFS file multihash - hash algorythm part
     * @param fileSize = IPFS file multihash - file size part
     * @return uint256 new Supply Node index value
     * @notice IPFS File multihash parts must be relatively valid.
     */
    function addSupplyNode (
        bytes32 fileDigest,
        uint8 fileMeta,
        uint8 fileSize
    ) public returns(uint256) {
        //Check
        require (fileDigest != 0x0, "Invalid file digest.");
        require (fileMeta != 0, "Invalid file meta.");
        require (fileSize != 0, "Invalid file size.");
        
        //Effect
        IPFile memory nodeFile = IPFile(fileDigest, fileMeta, fileSize);
        SupplyNode memory newNode = SupplyNode(msg.sender, nodeFile, 0);
        _supplyNode[++_nodeIndex] = newNode;
        
        //Reflect
        emit SupplyNodeAdded (_nodeIndex, msg.sender, now);
        return _nodeIndex;
    }
    
    /**
     * Transaction removeSupplyNode - Remove Supply Node by ID.
     * @param nodeId = Valid ID of a Supply Node
     * @return boolean transaction success
     * @notice must be owner of Supply Node, Supply Node must exist and be inactive.
     */
    function removeSupplyNode (uint256 nodeId) public returns(bool) {
        //Check
        require (nodeId != 0, "Node doesn't exist.");
        SupplyNode storage node = _supplyNode[nodeId];
        require (node.owner == msg.sender, "Must be node owner.");
        require (node.steps == 0, "Cannot remove node with active steps.");
        
        //Effect
        delete _supplyNode[nodeId].nodeFile;
        delete _supplyNode[nodeId];
        
        //Reflect
        emit SupplyNodeRemoved (nodeId, msg.sender, now);
        return true;
    }

    /**
     * Transaction approveNodeOp - Set approval for Supply Node operators by account address.
     * @param nodeId = Valid ID of a Supply Node
     * @return boolean transaction success
     * @notice must be owner of Supply Node.
     */
    function approveNodeOp (
        uint256 nodeId,
        address operator,
        bool approved
    ) public returns(bool) {
        //Check
        require (_supplyNode[nodeId].owner == msg.sender, "Node owner only.");
        require (operator != address(0), "Invalid operator address.");
        
        //Effect
        if (_supplyNode[nodeId].operator[operator] != approved) {
            _supplyNode[nodeId].operator[operator] = approved;
        }
        
        //Reflect
        emit NodeOpApproval (nodeId, operator, approved, now);
        return true;
    }

    /**
     * Transaction addSupplyItem - Add Supply Item to Supply Node as IPFS file.
     * @param nodeId = Origin Supply Node
     * @param fileDigest = IPFS file multihash - hash data part
     * @param fileMeta = IPFS file multihash - hash algorythm part
     * @param fileSize = IPFS file multihash - file size part
     * @return uint256 new Supply Item index value
     * @notice Must be Supply Node owner or operator, IPFS File multihash parts 
     * must be relatively valid.
     */
    function addSupplyItem (
        uint256 nodeId,
        bytes32 fileDigest,
        uint8 fileMeta,
        uint8 fileSize
    ) public returns(uint256) {
        //Check
        require (_supplyNode[nodeId].nodeFile.size != 0, "Invalid supply node.");
        require (_supplyNode[nodeId].owner == msg.sender ||
                 _supplyNode[nodeId].operator[msg.sender], "Invalid owner / operator.");
        require (fileDigest != 0x0, "Invalid file digest.");
        require (fileMeta != 0, "Invalid file meta.");
        require (fileSize != 0, "Invalid file size.");
        
        //Effect
        IPFile memory itemFile = IPFile(fileDigest, fileMeta, fileSize);
        _itemFile[++_itemIndex] = itemFile;
        _itemNode[_itemIndex] = nodeId;
        _itemStep[_itemIndex] = 0;//no steps
        
        //Reflect
        emit SupplyItemAdded (_itemIndex, nodeId, now);
        return _itemIndex;
    }
    
    /**
     * Transaction removeSupplyItem - Remove Supply Item by ID.
     * @param itemId = Valid Supply Item ID
     * @return boolean transaction success
     * @notice Must be Supply Node owner or operator, Item may not have active 
     * Supply Steps.
     */
    function removeSupplyItem (uint256 itemId) public returns(bool) {
        //Check
        require (_itemNode[itemId] == 0 || _itemFile[itemId].size != 0, "Invalid item.");
        require (_itemStep[itemId] == 0, "Cannot remove item with active steps.");
        uint256 nodeId = _itemNode[itemId];
        require (_supplyNode[nodeId].nodeFile.size != 0, "Invalid supply item root node.");
        require (_supplyNode[nodeId].owner == msg.sender ||
                 _supplyNode[nodeId].operator[msg.sender], "Invalid owner / operator.");
        
        //Effect
        delete _itemFile[itemId];
        delete _itemStep[itemId];
        delete _itemNode[itemId];
        
        //Reflect
        emit SupplyItemRemoved (itemId, nodeId, now);
        return true;
    }
    
    /**
     * Transaction addSupplyStep - Add Supply Step for Supply Item at Supply Node.
     * @param nodeId = Supply Node to end Supply Step to.
     * @param itemId = Supply Item this Supply Step references.
     * @param precedents = Array of Supply Step IDs, which this Supply Step extends.
     * @param fileDigest = IPFS file multihash - hash data part
     * @param fileMeta = IPFS file multihash - hash algorythm part
     * @param fileSize = IPFS file multihash - file size part
     * @return uint256 new supply step index value
     * @notice Must be valid Supply Step (see validateSupplyStep(), IPFS File 
     * multihash parts must be relatively valid.
     */
    function addSupplyStep (
        uint256 nodeId, 
        uint256 itemId,
        uint256[] memory precedents,
        bytes32 fileDigest,
        uint8 fileMeta,
        uint8 fileSize
    ) public returns(uint256) {
        //Check
        require (fileDigest != 0x0, "Invalid file digest.");
        require (fileMeta != 0, "Invalid file meta.");
        require (fileSize != 0, "Invalid file size.");
        require (validateSupplyStep(nodeId, itemId, precedents), "Invalid Supply Step.");
        
        //Effect
        IPFile memory stepFile = IPFile(fileDigest, fileMeta, fileSize);
        SupplyStep memory newStep = SupplyStep(nodeId, itemId, stepFile, precedents, 0);
        _supplyStep[++_stepIndex] = newStep;
        _itemStep[itemId] = _stepIndex;
        _supplyNode[nodeId].steps += 1;
        
        //Reflect
        emit SupplyStepAdded (_stepIndex, nodeId, itemId, now);
        return _stepIndex;
    }
    
    /**
     * Transaction removeSupplyStep - Remove Supply Step by ID.
     * @param stepId = Valid Supply Step ID
     * @return boolean transaction success
     * @notice Must be Supply Node owner or operator, must be Supply Items's 
     * last Supply Step, must not have any active Supply Node approvals.
     */
    function removeSupplyStep (uint256 stepId) public returns(bool) {
        //Check
        SupplyStep storage step = _supplyStep[stepId];
        uint256 nodeId = step.node;
        uint256 itemId = step.item;
        require (nodeId != 0, "Invalid step.");
        require (_supplyNode[nodeId].owner == msg.sender ||
                 _supplyNode[nodeId].operator[msg.sender], "Invalid owner / operator.");
        require (_itemStep[itemId] == stepId, "Only item's last step removable.");
        require (step.approvals == 0, "Cannot remove step with active approvals.");
        
        //Effect
        if (step.precedents.length > 0) {
            //reset itemStep to previous itemStep if exists in precedents.
            uint8 index = 0;
            while (index < step.precedents.length) {
                if (_supplyStep[step.precedents[index]].item == itemId) {
                    _itemStep[itemId] = step.precedents[index];
                    break;//can only be one
                } else index++;
            }
            if (index == step.precedents.length) _itemStep[itemId] = 0;
        }else _itemStep[itemId] = 0;
        if (_supplyNode[nodeId].steps > 0) _supplyNode[nodeId].steps -= 1;
        delete _supplyStep[stepId].stepFile;
        delete _supplyStep[stepId];
        
        //Reflect
        emit SupplyStepRemoved (stepId, nodeId, itemId, now);
        return true;
    }

    /**
     * Transaction requestSupplyStep - Request for Supply Node access to existing Supply Step.
     * @param stepId = Valid ID of a Supply Step beign requested.
     * @param nodeId = Valid ID of a Supply Node doing the requesting.
     * @return boolean transaction success
     * @notice Must be owner of Supply Node doing the request. Event-only effect, 
     * address of Supply Step's Supply Node owner included for event trigger.
     */
    function requestSupplyStep (
        uint256 stepId,
        uint256 nodeId
    ) public returns(bool) {
        //Check
        require (_supplyStep[stepId].node != 0, "Invalid step.");
        require (_supplyNode[nodeId].owner == msg.sender, "Node owner only.");
        
        //Reflect
        emit SupplyStepRequest (
            stepId, 
            _supplyNode[_supplyStep[stepId].node].owner, 
            nodeId, 
            now
        );
        return true;
    }

    /**
     * Transaction approveSupplyNode - Set approval for Supply Node access to existing 
     * Supply Step.
     * @param stepId = Valid ID of a Supply Step approving.
     * @param nodeId = Valid ID of a Supply Node being approved.
     * @param approved = State of approval.
     * @return boolean transaction success
     * @notice Must be owner of Supply Node owning Supply Step doing the approval. 
     * .
     */
    function approveSupplyNode (
        uint256 stepId,
        uint256 nodeId,
        bool approved
    ) public returns(bool) {
        //Check
        uint256 stepNode = _supplyStep[stepId].node;
        require (stepNode != 0, "Invalid step.");
        require (_supplyNode[stepNode].owner == msg.sender, "Step Node owner only.");
        
        //Effect
        if (_supplyStep[stepId].approval[nodeId] != approved) {
            _supplyStep[stepId].approval[nodeId] = approved;
            if (approved) _supplyStep[stepId].approvals += 1;
            else if (_supplyStep[stepId].approvals > 0) _supplyStep[stepId].approvals -= 1;
        }
        
        //Reflect
        emit SupplyNodeApproval (stepId, msg.sender, nodeId, approved, now);
        return true;
    }

    /**
     * View supplyNode - Get Supply Node data by ID.
     * @param nodeId = Valid ID of a Supply Node.
     * @return owner = Supply Node owner address.
     * @return fileDigest = Node File - IPFS file multihash - hash data part
     * @return fileMeta = Node File - IPFS file multihash - hash algorythm part
     * @return fileSize = Node File - IPFS file multihash - file size part
     * 
     */
    function supplyNode(uint256 nodeId) external view 
        returns (address owner, bytes32 fileDigest, uint8 fileMeta, uint8 fileSize ) {
        owner = _supplyNode[nodeId].owner;
        fileDigest = _supplyNode[nodeId].nodeFile.digest;
        fileMeta = _supplyNode[nodeId].nodeFile.meta;
        fileSize = _supplyNode[nodeId].nodeFile.size;
    }

    /**
     * View supplyItem - Get Supply Item data by ID.
     * @param itemId = Valid ID of a Supply Item.
     * @return nodeId =ID of Supply Item's origin Supply Node.
     * @return lastStep = Supply Item's last Supply Step ID. (zero if none)
     * @return fileDigest = Item File - IPFS file multihash - hash data part
     * @return fileMeta = Item File - IPFS file multihash - hash algorythm part
     * @return fileSize = Item File - IPFS file multihash - file size part
     * 
     */
    function supplyItem(uint256 itemId) external view 
        returns (uint256 nodeId, uint256 lastStep, bytes32 fileDigest, uint8 fileMeta, uint8 fileSize ) {
        nodeId = _itemNode[itemId];
        lastStep = _itemStep[itemId];
        fileDigest = _itemFile[itemId].digest;
        fileMeta = _itemFile[itemId].meta;
        fileSize = _itemFile[itemId].size;
    }

    /**
     * View supplyStep - Get Supply Step data by ID.
     * @param stepId = Valid ID of a Supply Step.
     * @return nodeId = ID of Supply Step's Supply Item's origin Supply Node.
     * @return itemId = Supply Item referenced by Supply Step.
     * @return precedents = Array of Supply Step IDs, which this Supply Step extends.
     * @return fileDigest = Step File - IPFS file multihash - hash data part
     * @return fileMeta = Step File - IPFS file multihash - hash algorythm part
     * @return fileSize = Step File - IPFS file multihash - file size part
     * 
     */
    function supplyStep(uint256 stepId) external view 
        returns (
            uint256 nodeId, 
            uint256 itemId, 
            uint256[] memory precedents,
            bytes32 fileDigest, 
            uint8 fileMeta, 
            uint8 fileSize 
        ) {
        nodeId = _supplyStep[stepId].node;
        itemId = _supplyStep[stepId].item;
        precedents = _supplyStep[stepId].precedents;
        fileDigest = _supplyStep[stepId].stepFile.digest;
        fileMeta = _supplyStep[stepId].stepFile.meta;
        fileSize = _supplyStep[stepId].stepFile.size;
    }

    /**
     * View validateSupplyStep - Validates a potential Supply Step entry to see if it's valid.
     * @param nodeId = ID of Supply Supply Node to create Supply Step on.
     * @param itemId = Supply Item referenced by Supply Step.
     * @param precedents = Array of Supply Step IDs, which this Supply Step extends.
     * @return boolean = valid or not
     * @notice this check always occurs before adSupplyStep transaction, however can be called
     * independently first to check vaidiity, to avoid transaction fail.
     * Checks: Node is valid, sender is owner or operator of Supply Node adding the step, 
     * item referenced is valid, all included precedents are themselves last steps of there 
     * respective items, the nodeId adding them has approval to extend those steps, and adding 
     * a step that is not the first step of a given item, must include that item's last step 
     * as a precedent, given approval to do so.
     * 
     */
    function validateSupplyStep (
        uint256 nodeId, 
        uint256 itemId,
        uint256[] memory precedents
    ) public view returns(bool) {
        if (_supplyNode[nodeId].nodeFile.size == 0) return false;
        if (_supplyNode[nodeId].owner != msg.sender &&
             !_supplyNode[nodeId].operator[msg.sender]) return false;
        if (_itemFile[itemId].size == 0) return false;
        uint8 itemRepeatStep = 0;
        if (precedents.length > 0) {
            uint8 index = 0;
            while (index < precedents.length) {
                if (_supplyStep[precedents[index]].item == 0 || 
                    !(_supplyStep[precedents[index]].node == nodeId || 
                        _supplyStep[precedents[index]].approval[nodeId]) ||
                    _itemStep[_supplyStep[precedents[index]].item] != precedents[index]) {
                    return false;
                } 
                if (_supplyStep[precedents[index]].item == itemId) itemRepeatStep++;
                index++;
            }
        }
        if (itemRepeatStep > 1 || (itemRepeatStep == 0 && _itemStep[itemId] != 0)) return false;
        return true;
    }

    /**
     * View isNodeOp - Check address as Node operator.
     * @param nodeId = Valid ID of a Supply Node.
     * @param operator = account address.
     * @return boolean = is node operator
     * @notice Supply Node owner only
     */
    function isNodeOp(uint256 nodeId, address operator) external view returns (bool) {
        require (_supplyNode[nodeId].owner == msg.sender);
        return _supplyNode[nodeId].operator[operator];
    }

    /**
     * View itemLastStep - Get last Supply Step of given Supply Item ID
     * @param itemId = Valid ID of a Supply Item.
     * @return stepId = Supply Step ID
     */
    function itemLastStep(uint256 itemId) public view returns (uint256 stepId) {
       stepId = _itemStep[itemId];
    }
    
    /**
     * View stepPrecedents - Get precedents of given Supply Step ID
     * @param stepId = Valid ID of a Supply Step.
     * @return precedents = Array of Supply Step IDs
     */
    function stepPrecedents(uint256 stepId) public view returns (uint256[] memory precedents) {
       precedents = _supplyStep[stepId].precedents;
    }

    /**
     * View stepNodeApproved - Get Supply Step approval status for Supply Node
     * @param stepId = Valid ID of a Supply Step.
     * @param nodeId = Valid ID of a Supply Node.
     * @return approved = Boolean approval status
     */
    function stepNodeApproved(uint256 stepId, uint256 nodeId) external view returns (bool approved) {
        approved = (_supplyStep[stepId].node == nodeId || _supplyStep[stepId].approval[nodeId]);
    }
    
    //developer only destroy method
    function destroy() external {
       require (_developer == msg.sender);
       selfdestruct(_developer);
    }
    
    //Return to sender, any abstract transfers
    function () external payable { msg.sender.transfer(msg.value); }
}
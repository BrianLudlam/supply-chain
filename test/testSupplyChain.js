const truffleAssert = require('truffle-assertions');
const SupplyChain = artifacts.require("SupplyChain");

let supplyChain;

contract("SupplyChain", (accounts) => {

  const dev = accounts[0];
  const alice = accounts[1];
  const aliceOp = accounts[2];
  const bob = accounts[3];

  beforeEach(async () => {
    supplyChain = await SupplyChain.new({from: dev});
  });

  afterEach(async () => {
    await supplyChain.destroy({from: dev});
  });

  it("Acts like a SupplyChain", async () => {

    //Alie adds new supply node
    const aliceNode1 = await assertAddSupplyNode(testFile, alice);

    //Alice adds a new supply item to supply node
    const aliceItem1 = await assertAddSupplyItem(aliceNode1.toString(), testFile, alice);
    
    //Alice adds item's first step
    const aliceStep1 = await assertAddSupplyStep(
      aliceNode1.toString(), 
      aliceItem1.toString(), 
      [],//no precedents
      testFile, 
      alice
    );

    //alice adds another supply node
    const aliceNode2 = await assertAddSupplyNode(testFile, alice);

    //Alice gives new node permission to extend step 1
    await assertApproveSupplyNode(aliceStep1, aliceNode2, true, alice);

    //Alice adds an operator aliceOp for aliceNode2
    await assertApproveNodeOp(aliceNode2.toString(), aliceOp, true, alice);

    //aliceOp adds aliceItem1's second step
    const aliceStep2 = await assertAddSupplyStep(
      aliceNode2.toString(), 
      aliceItem1.toString(), 
      [aliceStep1.toString()],
      testFile, 
      aliceOp
    );

    //Bob adds new supply node
    const bobNode1 = await assertAddSupplyNode(testFile, bob);

    //Bob adds a new supply item
    const bobItem1 = await assertAddSupplyItem(bobNode1.toString(), testFile, bob);

    //Bob adds item's first step
    const bobStep1 = await assertAddSupplyStep(
      bobNode1.toString(), 
      bobItem1.toString(), 
      [],//no precedents
      testFile, 
      bob
    );

    //Bob requests approval for Bob's Supply Node to add a Supply Step from Alice's Supply Step
    await assertRequestSupplyStep (aliceStep2, bobNode1, bob);

    //Alice gives bob's node permission to extend Alice's supply step
    await assertApproveSupplyNode(aliceStep2, bobNode1, true, alice);
    
    //Bob adds bobItem1 second step, extending aliceItem1's second step
    const bobStep2 = await assertAddSupplyStep(
      bobNode1.toString(), 
      bobItem1.toString(), 
      [bobStep1.toString(), aliceStep2.toString()],
      testFile, 
      bob
    );

    //Bob removes supply step 2
    await assertRemoveSupplyStep(bobStep2, bob);

    //Bob removes supply step 1
    await assertRemoveSupplyStep(bobStep1, bob);

    //Bob removes supply item 1
    await assertRemoveSupplyItem(bobItem1, bob);

    //Alice removes bob's node permission to extend Alice's supply step
    await assertApproveSupplyNode(aliceStep2, bobNode1, false, alice);

    //Bob removes supply node 1
    await assertRemoveSupplyNode(bobNode1, bob);

    //Alice removes supply step 2
    await assertRemoveSupplyStep(aliceStep2, alice);

    //Alice removes second node permission to first step
    await assertApproveSupplyNode(aliceStep1, aliceNode2, false, alice);

    //Alice removes approval from operator aliceOp for aliceNode2
    await assertApproveNodeOp(aliceNode2.toString(), aliceOp, false, alice)

    //Alice removes supply node 2
    await assertRemoveSupplyNode(aliceNode2, alice);

    //Alice removes supply step 1
    await assertRemoveSupplyStep(aliceStep1, alice);

    //Alice removes supply item 1
    await assertRemoveSupplyItem(aliceItem1, alice);

    //Alice removes supply node 1
    await assertRemoveSupplyNode(aliceNode1, alice);

  });

});

const testFile = {
  digest: '0x1111111111111111111111111111111112222222222222222222222222222222',
  meta: 22,
  size: 32
}

const logThis = (obj) => console.log('LOG - ',obj);

const assertAddSupplyNode = async (file, from) => {
  const tx = await supplyChain.addSupplyNode (
    file.digest,
    file.meta, 
    file.size, 
    {from}
  );
  let nodeId = '0';
  assert.equal (tx.receipt.status, true, "addSupplyNode - tx status false");
  truffleAssert.eventEmitted(tx, 'SupplyNodeAdded', (e) => ((nodeId = e.nodeId.toString()) !== '0'));
  assert.equal (nodeId !== '0', true, "SupplyNodeAdded event fail.");

  const node = await supplyChain.supplyNode (nodeId, {from});
  assert.equal (
    node.fileDigest.toString() === file.digest &&
    parseInt(node.fileMeta) === file.meta &&
    parseInt(node.fileSize) === file.size, 
    true, "addSupplyNode - node check fail"
  );

  return nodeId;
}

const assertRemoveSupplyNode = async (nodeId, from) => {
  const tx = await supplyChain.removeSupplyNode (
    nodeId,
    {from}
  );
  assert.equal (tx.receipt.status, true, "removeSupplyNode - status false");
  truffleAssert.eventEmitted(tx, 'SupplyNodeRemoved', (e) => (
    nodeId === e.nodeId.toString()
  ));
}

const assertApproveNodeOp = async (nodeId, operator, approved, from) => {
  const tx = await supplyChain.approveNodeOp (
    nodeId,
    operator, 
    approved,
    {from}
  );
  assert.equal (tx.receipt.status, true, "approveOperator - status false");
  truffleAssert.eventEmitted(tx, 'NodeOpApproval', (e) => (
    e.nodeId.toString() === nodeId && e.operator === operator && e.approved === approved
  ));

  const opCheck = await supplyChain.isNodeOp (nodeId, operator, {from});
  assert.equal (opCheck, approved, "approveOperator - check");
}

const assertAddSupplyItem = async (nodeId, file, from) => {
  const tx = await supplyChain.addSupplyItem (
    nodeId,
    file.digest,
    file.meta, 
    file.size, 
    {from}
  );
  let itemId = '0';
  assert.equal (tx.receipt.status, true, "addSupplyItem - status false");
  truffleAssert.eventEmitted(tx, 'SupplyItemAdded', (e) => ((itemId = e.itemId.toString()) !== '0'));
  assert.equal (itemId !== '0', true, "SupplyItemAdded event fail.");

  const item = await supplyChain.supplyItem (itemId, {from});
  assert.equal (
    item.nodeId.toString() === nodeId &&
    item.fileDigest.toString() === file.digest &&
    parseInt(item.fileMeta) === file.meta &&
    parseInt(item.fileSize) === file.size, 
    true, "addSupplyItem - item check fail"
  );

  return itemId;
}

const assertRemoveSupplyItem = async (itemId, from) => {
  const tx = await supplyChain.removeSupplyItem (
    itemId,
    {from}
  );
  assert.equal (tx.receipt.status, true, "removeSupplyItem - status false");
  truffleAssert.eventEmitted(tx, 'SupplyItemRemoved', (e) => (
    itemId === e.itemId.toString()
  ));
}

const assertAddSupplyStep = async (nodeId, itemId, precedents, file, from) => {
  const tx = await supplyChain.addSupplyStep (
    nodeId,
    itemId,
    precedents,
    file.digest,
    file.meta, 
    file.size, 
    {from}
  );
  let stepId = '0';
  assert.equal (tx.receipt.status, true, "addSupplyStep - status false");
  truffleAssert.eventEmitted(tx, 'SupplyStepAdded', (e) => (
    (stepId = e.stepId.toString()) !== '0' && nodeId === e.nodeId.toString() && itemId === e.itemId.toString()
  ));
  assert.equal (stepId !== '0', true, "SupplyStepAdded event fail.");

  lastStep = await supplyChain.itemLastStep (itemId, {from});
  assert.equal (lastStep, stepId, "addSupplyStep - lastStep check fail");

  const step = await supplyChain.supplyStep (stepId, {from});
  assert.equal (
    step.nodeId.toString() === nodeId &&
    step.itemId.toString() === itemId &&
    step.precedents.every((one) => precedents.includes(one.toString())) &&
    step.fileDigest.toString() === file.digest &&
    parseInt(step.fileMeta) === file.meta &&
    parseInt(step.fileSize) === file.size, 
    true, "addSupplyStep - Step check fail"
  );

  return stepId;
}

const assertRemoveSupplyStep = async (stepId, from) => {
  const tx = await supplyChain.removeSupplyStep (
    stepId,
    {from}
  );
  assert.equal (tx.receipt.status, true, "removeSupplyStep - status false");
  truffleAssert.eventEmitted(tx, 'SupplyStepRemoved', (e) => (
    stepId === e.stepId.toString()
  ));
}

const assertRequestSupplyStep = async (stepId, nodeId, from) => {
  const tx = await supplyChain.requestSupplyStep (
    stepId,
    nodeId,
    {from}
  );
  assert.equal (tx.receipt.status, true, "requestSupplyStep - status false");
  truffleAssert.eventEmitted(tx, 'SupplyStepRequest', (e) => (
    e.stepId.toString() === stepId && e.nodeId.toString() === nodeId
  ));
}

const assertApproveSupplyNode = async (stepId, nodeId, approved, from) => {
  const tx = await supplyChain.approveSupplyNode (
    stepId,
    nodeId, 
    approved, 
    {from}
  );
  assert.equal (tx.receipt.status, true, "approveSupplyNode - status false");
  truffleAssert.eventEmitted(tx, 'SupplyNodeApproval', (e) => (
    e.stepId.toString() === stepId && e.nodeId.toString() === nodeId && e.approved === approved && from === e.owner
  ));
}




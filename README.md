# Supply Chain prototype contract implementation

A general Supply Chain smart contract implementation. All Supply Chain relevant data is stored on-chain, with all data erroneous to the system stored on IPFS. All information in the system, whether on-chain or on IPFS, is impossible to change without a contract event logging the change, and all versions of all data can be permanently referenced on IPFS. It is not possible to hide anything in this system: past, present, or future. 

A Supply Chain is defined in this system as a Directed Acyclic Graph of supply steps that follow the production of something back to it's conception. A supply step always references a single item in the system, and may extend one or more previous supply steps, or precedents. A new step may only be added as a first step, or the last step of an existing supply chain. Approval must be granted to create a new supply step, which extends a supply step not owned directly.

The Supply Chain system consists of: Supply Nodes, Supply Items, and Supply Steps. 

## Supply Nodes

Supply Nodes represent real-world supply chain locations, such as raw resource collection/exploitation, production, factory, distribution, wholesale, and retail locations around the world. A Supply Node is created with an object file containing all information about the Supply Node. The Supply Node file is written to IPFS, with file signature written to contract. A Supply Node can be created by anyone with an Ethereum account, and can be assigned other accounts as operators to manage contract interaction. A Supply Node can introduce new Supply Items, and have any number of Supply Steps, involving it's own Supply Items, and/or that of other Supply Nodes in the system. 

## Supply Items

A Supply Item represents real-world created entities, such as products, services, or even information. A Supply Item is created with an object file containing all information about the Supply Item. The Supply Item file is written to IPFS, with file signature written to contract. A Supply Item is introduced to the system by a Supply Node, which retains ownership/control of that Supply Item's initial Supply Steps. All Supply Items reference the root Supply Node that they started from. Each Supply Item has a number of Supply Steps which follow it's supply chain back to various points of conception. 

## Supply Steps

A Supply Step represents steps in the supply chain for a given Supply Item. A Supply Step is created with an object file containing all information about the Supply Step. The Supply Step file is written to IPFS, with file signature written to contract. Supply Steps are recursive, in that they may refer to a number of preceding Supply Steps. Therefore, any Supply Step can be traced back, each step, to it's first Supply Step in the system. That first Supply Step may refer to the Supply Steps of other Supply Items in the system, and those traced back to their origins, etc. The owner or operator of a Supply Node can always add a Supply Step to a Supply Item owned by that Supply Node. However, in order to create a Supply Step for a Supply Item that is not owned by that Supply Node, permission must be requested and granted to the owner of the Supply Node, by the owner of the Supply Node owning the last Supply Step of that given Supply Item. 

## An Example

As an example, let's say the owner of "Sherwood Forest Lumberyard", adds their lumber yard to the system, as a Supply Node. The owner also adds their manager as an operator on that Supply Node. The manager then takes over by adding a Supply Item to the Supply Node, called "Sherwood Forest Lumber". The manager then creates a first Supply Step for their lumber item, called "Lumber Resource Collection" referencing the location of resources collected, and then creates a series of other Supply Steps involving in-house production, ending with a final product of packaged ready-to-ship lumber in well-defined quantities. That final product, regardless of how many Supply Steps leading up to it, will have a final Supply Step that represents it's "Last Supply Step" ready for other Supply Nodes to add to the supply chains with their own supply steps which require lumber. 

The process continues when another Supply Node owner/operator searches for a lumber supplier, and finds "Sherwood Forest Lumber" as a Supply Item. Every Supply Item in the system can only have one last Supply Step, so the Supply Node needing lumber, puts in a Supply Request to the last Supply Step of "Sherwood Forest Lumber". The lumber Supply Node receives the request by contract event and responds by, ignoring, or allowing the request, by approving the Supply Node to add a new Supply Step to their supply chain which includes their lumber Supply Item. Once a Supply Node is approved for access to a given Supply Step, then they can create a new Supply Step on their own Supply Node for some other Supply Item including the lumber Supply Step as a precedent. Continuing this same process all the way to - let's say, retail dining room table product. The table can then be traced back through all of it's preceding supply steps, to the forest where the wood came from. The system is prepared to handle far more complex supply chains, but the process is always the same.

## Compile, Test, Deploy with Truffle

## Author Brian Ludlam - brianludlam@gmail.com
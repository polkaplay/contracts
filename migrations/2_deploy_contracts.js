const PolkaPlayNFT = artifacts.require("PolkaPlayNFT");
const PolkaPlaySales = artifacts.require("PolkaPlaySales");
const PoloAuctionEngine = artifacts.require("PoloAuctionEngine");
const PoloToken = artifacts.require("PoloToken");

module.exports = async function(deployer) {
  //Deploy  Token
  await deployer.deploy(PoloToken);
  const token = await PoloToken.deployed();

    //Deploy  NFT
//   await deployer.deploy(PolkaPlayNFT);
//   const nft = await PolkaPlayNFT.deployed();
// 
//   await deployer.deploy(PolkaPlaySales,nft.address, 1);
// 
//   const auctions = await deployer.deploy(PoloAuctionEngine);


};

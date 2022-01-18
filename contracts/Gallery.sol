// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.0;
import "./IERC721Receiver.sol";
import "./TICKET.sol";
import "./Painting.sol";

contract Gallery is Ownable, IERC721Receiver{

    //struct to store a stake's token, owner, earnings
    struct Stake {
        uint16 tokenId;
        uint80 value;
        address owner;
    }

    //add events
    event TokenStaked(address owner, uint256 tokenId, uint256 value);
    event PaintingClaimed(uint256 tokenId, uint256 earned, bool unstaked);
    event RobberClaimed(uint256 tokenId, uint256 earned, bool unstaked);

    //reference painting NFT contract
    Painting paintingg;
    //reference to $TICKET contract for minting earnings
    TICKET ticket;

    // reference to Entropy
    // IEntropy entropy;

    //maps tokenId to stake
    mapping(uint256 => Stake) public gallery;
    //maps rarity to all robbers stakes with that rarity
    mapping(uint256 => Stake) public group;
    //track location of robber in group
    mapping(uint256 => uint256) public groupIndices;

    //total rarity scores stakes
    uint256 public totalRarityStaked = 0;
    //any rewards distributed when no CNs are staked
    uint256 public unaccountedRewards = 0;
    //amount of $TICKET due for each rarity point staked
    uint256 public ticketsPerRarityScore = 0;

    uint256 public ticketForRobbers = 0;

    // Portaits earn 10000 $ticket per day
    uint256 public constant DAILY_TICKET_RATE = 100000000000000000;
    // paintinggs must have 2 days worth of $TICKET to unstake or else i
    uint256 public constant MINIMUM_TO_EXIT = 2 days;
    // Robbers take a 15% tax on all $Robbers claimed
    uint256 public constant TICKET_CLAIM_TAX_PERCENTAGE = 20;
    // there will only ever be (roughly) 1.8 billion $TICKET earned through staking
    uint256 public constant MAXIMUM_GLOBAL_TICKETS = 1800000000000000000000;

    // amount of $TICKET earned so far
    uint256 public totalTicketEarned;
    // number of Paintings staked in the Hotel
    uint256 public totalPaintingsStaked;
    // the last time $TICKET was claimed
    uint256 public lastClaimTimestamp;

    uint256 public totalRobbersStaked = 0;

    


    /**
     * @param _painting reference to the painting NFT contract
     * @param _ticket reference to the $TICKET token
     */
    constructor(address _painting, address _ticket) {
        painting = Painting(_painting);
        ticket = TICKET(_ticket);
    }

    /** STAKING */
    
    /**
     * adds Painting and Robbers to the Gallery and Group
     * @param account the address of the staker
     * @param tokenIds the IDs of the painting and Robbers to stake
     */
    function addManyToGalleryAndGroup(address account, uint256[] calldata tokenIds)
        public
    {
        // require(
        //     account == _msgSender() || _msgSender() == address(cat),
        //     "DO NOT GIVE YOUR TOKENS AWAY"
        // );
        // require(tx.origin == _msgSender());

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // to ensure it's not in buffer
            // require(cat.totalSupply() >= tokenIds[i] + cat.maxMintAmount());
            
            if (_msgSender() != address(painting)) {
                // dont do this step if its a mint + stake
                require(
                    painting.ownerOf(tokenIds[i]) == _msgSender(),
                    "NOT YOUR TOKEN"
                );
                //cat.transferFrom(_msgSender(), address(this), tokenIds[i]);
            } else if (tokenIds[i] == 0) {
                continue; // there may be gaps in the array for stolen tokens
            }

            if (ispPainting(tokenIds[i])){
             _addPaintinToGallery(account, tokenIds[i]);
            }
            else {
            _addRobberToGroup(account, tokenIds[i]);
            }
        }
    }
    
    /**
     * adds a single painting to the Gallery
     * @param account the address of the staker
     * @param tokenId the ID of the Sheep to add to the Barn
     */
    function _addPaintinToGallery(address account, uint256 tokenId)
        public
        // whenNotPaused
        // _updateEarnings
    {
        painting.transferFrom(_msgSender(), address(this), tokenId);

        painting[tokenId] = Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        });
        //cat.approve(address(this), 1);
        totalPaintingsStaked += 1;
        

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _addRobberToGroup(address account, uint256 tokenId) public {
        
        painting.transferFrom(_msgSender(), address(this), tokenId);

        group[tokenId] = Stake({
            owner: account,
            tokenId: uint16(tokenId),
            value: uint80(block.timestamp)
        });

        totalRobbersStaked += 1;

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    /** CLAIMING / UNSTAKING */
    function claimManyFromGalleryAndGroup(uint16[] calldata tokenIds, bool unstake, uint256 volume)
    external
    // _updateEarnings
    {
        require(tx.origin == _msgSender());

        uint256 owed = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (isPainting(tokenIds[i])){

            owed += _claimPaintingFromGallery(tokenIds[i], unstake, volume);

            } else {

            owed += _claimRobberFromGroup(tokenIds[i], unstake);

            }
        }

        if (owed == 0) return;

        ticket.mint(_msgSender(), owed);
    }


    function _claimPaintingFromGallery(uint256 tokenId, bool unstake, uint256 volume)
    internal
    returns (uint256 owed)
    {
        Stake memory stake = gallery[tokenId];

        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");

        owed = ((block.timestamp - stake.value) * DAILY_TICKET_RATE * volume) / 1 days;

        if (unstake){

            //50% chance to have all $TICKETs stolen
            if (painting.generateSeed(totalCatsStaked,10) > 5){
                _payRobberTax(owed);
                owed = 0;
            }
            

            totalPaintingsStaked -= 1;
                    
            //send back painting
            painting.safeTransferFrom(address(this), _msgSender(), tokenId, "");
            delete gallery[tokenId];
        } else {
            
            _payRobberTax((owed * TICKET_CLAIM_TAX_PERCENTAGE)/100);

            owed = (owed * (100 - TICKET_CLAIM_TAX_PERCENTAGE)) / 100;

            gallery[tokenId] = Stake({
                owner: _msgSender(),
                tokenId: uint16(tokenId),
                value: uint80(block.timestamp)
            });

        
        }
        
        

        emit PaintingClaimed(tokenId, earned, unstaked);

    }

    function _claimRobberFromGroup(uint256 tokenId, bool unstake) internal returns (uint256){
        require(
            painting.ownerOf(tokenId) == address(this),
            "NOT THE OWNER"
        );

        Stake memory stake = group[tokenId];

        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");

        uint256 owed = ticketForRobbers / totalRobbersStaked;

        if (unstake){
            
            totalRobbersStaked -= 1;

            

            delete group[tokenId];

            painting.safeTransferFrom(address(this), _msgSender(), tokenId,"");
        } else {
        
            group[tokenId] = Stake({
                owner: _msgSender(),
                tokenId: uint16(tokenId),
                value: uint80(block.timestamp)
            });

        }
        emit RobberClaimed(tokenId, owed, unstake);
    }

    function randomRobber(uint256 seed) external view returns(address){

        if (totalRobbersStaked == 0){
            return address(0x0);
        }
        return address(0x0);


    }

    function isPainting(uint256 tokenId) public view returns (bool){
        if (tokenId >= 45000){
            return false;
        }
        return true;
    }

    function _payRobberTax(uint256 amount) internal {
        if (totalRobbersStaked == 0){
            unaccountedRewards += amount;
            return;
        }

        ticketForRobbers += amount + unaccountedRewards;
        unaccountedRewards = 0;
        
    }
    
    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send tokens to Barn directly");
        return IERC721Receiver.onERC721Received.selector;
    }


}
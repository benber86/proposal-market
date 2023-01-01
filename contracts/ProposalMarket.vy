# @version 0.3.7


struct Offer:
        owner: address
        script: Bytes[1024]
        metadata: String[64]
        tip: uint256
        claimer: address
        claim_expiry: uint256


struct VoteInfo:
        open: bool
        executed: bool
        startDate: uint64
        snapshotBlock: uint64
        supportRequired: uint64
        minAcceptQuorum: uint64
        yea: uint256
        nay: uint256
        votingPower: uint256
        script: Bytes[1024]


interface Ownership:
    def newVote(
        _executionScript: Bytes[1024],
        _metadata: String[64],
        _castVote: bool,
        _executesIfDecided: bool,
    ) -> uint256: nonpayable
    def getVote(_voteId: uint256) -> VoteInfo: view


# Events
event OfferPlaced:
    sender: indexed(address)
    offer_id: uint256
    tip: uint256


event OfferClaimed:
    claimer: indexed(address)
    offer_id: uint256


event OfferWithdrawn:
    offer_id: uint256


event OfferFulfilled:
    filler: indexed(address)
    offer_id: uint256
    vote_id: uint256


OWNERSHIP: public(
    constant(address)
) = 0xE478de485ad2fe566d49342Cbd03E49ed7DB3356
CLAIM_DURATION: public(constant(uint256)) = 60 * 12
offers: HashMap[uint256, Offer]
offer_count: uint256


@internal
def _is_offer_locked_for_caller(offer: Offer) -> bool:
    if msg.sender == offer.claimer:
        return False
    elif block.timestamp > offer.claim_expiry:
        return False
    return True


@payable
@external
def place_offer(script: Bytes[1024], metadata: String[64]) -> uint256:
    assert msg.value > 0
    offer: Offer = Offer(
        {
            owner: msg.sender,
            script: script,
            metadata: metadata,
            tip: msg.value,
            claimer: msg.sender,
            claim_expiry: 1,
        }
    )
    self.offer_count += 1
    self.offers[self.offer_count] = offer
    log OfferPlaced(msg.sender, self.offer_count, msg.value)
    return self.offer_count


@nonreentrant("lock")
@external
def fulfill_offer(offer_id: uint256, vote_id: uint256) -> uint256:
    offer: Offer = self.offers[offer_id]
    assert not self._is_offer_locked_for_caller(offer)
    vote_info: VoteInfo = Ownership(OWNERSHIP).getVote(vote_id)
    assert convert(vote_info.startDate, uint256) > block.timestamp
    assert vote_info.script == offer.script
    assert vote_info.open
    self.offers[offer_id] = empty(Offer)
    send(msg.sender, offer.tip)
    log OfferFulfilled(msg.sender, offer_id, vote_id)
    return vote_id


@external
def claim_offer(offer_id: uint256):
    offer: Offer = self.offers[offer_id]
    assert not self._is_offer_locked_for_caller(offer)
    self.offers[offer_id].claimer = msg.sender
    self.offers[offer_id].claim_expiry = block.timestamp + CLAIM_DURATION
    log OfferClaimed(msg.sender, offer_id)


@nonreentrant("lock")
@external
def withdraw_offer(offer_id: uint256):
    offer: Offer = self.offers[offer_id]
    self.offers[offer_id] = empty(Offer)
    assert msg.sender == offer.owner
    assert offer.claim_expiry < block.timestamp
    send(msg.sender, offer.tip)
    log OfferWithdrawn(offer_id)


@external
@payable
def __default__():
    pass

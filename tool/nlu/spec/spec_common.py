# Helpers shared by the spec's parts (intents_core.py, intents_more.py).


def I(id, group, maps, when, not_when, conf, req, opt, ex, neg, phone_only=False, note=''):
    """One intent: when it is meant and when not, what it gets mixed up with,
    its slots, 10 right examples and 5 look-alikes that are another intent."""
    assert len(ex) == 10, (id, len(ex))
    assert len(neg) == 5, (id, len(neg))
    return dict(id=id, group=group, maps_to=maps, when=when, not_when=not_when,
                confusable=[dict(intent=a, difference=b) for a, b in conf],
                required=req, optional=opt, phone_only=phone_only, examples=ex,
                negatives=[dict(text=t, intent=i) for t, i in neg], note=note)

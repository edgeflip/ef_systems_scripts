#!/bin/python
import sys
import urllib2
import json
import argparse
import httplib
from urllib import urlencode
from datetime import date




FB_APP_ID = '471727162864364'
FB_APP_SECRET = '120fe5e6d5bffa6a9aa3bf075bd3076a'
DEFAULT_PASSWORD = 'edgeflip'




def get_app_token(app_id, app_secret):              
    # https://graph.facebook.com/oauth/access_token?client_id=111399285589490&client_secret=ca819150ad771e5cbcacf60bd88c04d7&grant_type=client_credentials
    url = "https://graph.facebook.com/oauth/access_token?client_id=" + app_id
    url += "&client_secret=" + app_secret + "&grant_type=client_credentials"
    line = urllib2.urlopen(url).readline() 
    # should have: 'access_token=471727162864364|jVJvD2JfB6iwFvx9evMLOgLQiNg'
    tag = 'access_token='
    pos = line.index(tag) + len(tag)
    tok = line[pos:]
    return tok

def get_user_token(fbid, app_id, app_token):
    for user in get_test_users(app_id, app_token):
        if user['id'] == fbid:
            return user['access_token']
    else:
         return False

def get_test_users(app_id, app_token):
    # https://graph.facebook.com/111399285589490/accounts/test-users?access_token=111399285589490|ChvF9GrYd2K9cHq07NQmcSVhDsc
    url = "https://graph.facebook.com/" + app_id + "/accounts/test-users?access_token=" + app_token
    users_json = json.load(urllib2.urlopen(url))['data']  
    # each entry should have: id, access_token, login_url
    return users_json

def info_from_fbid(fbid, token=None):
    url = "https://graph.facebook.com/" + fbid
    if token is not None:
        url += "?access_token=" + token
    return json.load(urllib2.urlopen(url))

def infos_from_fbids(fbids, app_token):
    queries = []
    for fbid in fbids:
        queries.append({'method':'GET', 'relative_url':fbid})
    url = "https://graph.facebook.com/"
    encodes = urlencode([
        ('batch', json.dumps(queries)),
        ('access_token', app_token),
    ])
    responses = json.load(urllib2.urlopen(url, encodes))
    responses.reverse()  # because I like looking at the new ones last
    # print "got responses: " + str(responses)
    return [json.loads(resp['body']) for resp in responses]

def create_test_user(app_id, app_token, name=None):
    url = 'https://graph.facebook.com/' + app_id + '/accounts/test-users'
    unencodes = [
        ('installed', 'true'),
        ('permissions', 'read_stream,user_photos,friends_photos,email,user_birthday,' +
            'friends_birthday,user_about_me,user_location,friends_location,user_likes,' +
            'friends_likes,user_interests,friends_interests'),
        ('access_token', app_token),
    ]
    if name is not None:
        unencodes.append(('name', name))

    # should get: id, access_token, login_url, email, password
    response = json.load(urllib2.urlopen(url, urlencode(unencodes)))
    return response

# def create_test_user_httplib(name, app_id, app_token):
#     conn = httplib.HTTPSConnection('graph.facebook.com')
#     url = "/%s/accounts/test-users?access_token=%s&installed=true&name=%s" % (app_id, app_token, name)
#     conn.request('POST', url)
#     resp = conn.getresponse()
#     content = resp.read()
#     print "create got: " + content
#     return (content == 'true')

# N.B.: calling this for password will invalidate preexisting access token
def update_user(fbid, user_token, name=None, passwd=None):
    url = 'https://graph.facebook.com/' + fbid
    unencodes = [ ('access_token', user_token) ]
    if (name is not None):
        unencodes.append(('name', name))
    if (passwd is not None):
        unencodes.append(('password', passwd))    
    print url
    print urlencode(unencodes)
    return json.load(urllib2.urlopen(url, urlencode(unencodes)))

def label_name(fbid, user_token):
    info = info_from_fbid(fbid, user_token)

    bdate = None
    if 'birthday' in info:
        if len(info['birthday']) == 10:
            mmddyyyy = info['birthday']
            bdate = date(int(mmddyyyy[6:]), int(mmddyyyy[:2]), int(mmddyyyy[3:5]))
        elif len(info['birthday']) == 7:
            mmyyyy = info['birthday']
            bdate = date(int(mmyyyy[3:]), int(mmyyyy[:2]), 1)
        elif len(info['birthday']) == 4:
            yyyy = info['birthday']
            bdate = date(int(yyyy), 1, 1)
        print "birthday is '%s', parsed to %s" % (info['birthday'], str(bdate))
    if bdate is not None:
        age = int((date.today() - bdate).days/365.2425)
        agestr = int2str(age)
        print "age is %d, agestr is '%s'" % (age, agestr)
    else:
        agestr = ""

    if 'location' in info:
        loc = info['location']['name'].replace(", ", "-").replace(" ", "")
    else:
        loc = "Nowhere"

    label = " ".join([info.get('gender').title(), agestr, loc])
    print "renaming %s %s -> %s" % (fbid, info['name'], label)
    update_user(fbid, user_token, name=label)

def delete_user(fbid, app_id, app_token):
    conn = httplib.HTTPSConnection('graph.facebook.com')
    conn.request('DELETE', "/%s?access_token=%s" % (fbid, app_token))
    resp = conn.getresponse()
    content = resp.read()
    print "delete got: " + content
    return (content == 'true')

def make_friends(infos):
    link_count = 0
    fail_count = 0
    for i in range(len(infos)):
        info1 = infos[i]
        for info2 in infos[i+1:]:            
            url = 'https://graph.facebook.com/' + info1['id'] + '/friends/' + info2['id'] 
            encodes = urlencode([('access_token', info1['access_token'])])
            response = json.load(urllib2.urlopen(url, encodes))
            if response:
                url = 'https://graph.facebook.com/' + info2['id'] + '/friends/' + info1['id']
                encodes = urlencode([('access_token', info2['access_token'])])
                response = json.load(urllib2.urlopen(url, encodes))
                if response:
                    link_count += 1
                else:
                    fail_count += 1
            else:
                fail_count += 1
    return link_count

def list_to_dict(dict_list, key):
    return dict([(d[key], d) for d in dict_list])

def int2str(number):
    ones = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
            'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen',
            'Eighteen', 'Nineteen']
    tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety']

    if number < len(ones):
        return ones[number]
    else:
        ones_digit = int(str(number)[1])
        tens_digit = int(str(number)[0])
        ret = tens[tens_digit]
        if ones_digit > 0:
            ret += ones[ones_digit]
        return ret

    words = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine']
    return "".join([ words[int(digit)] for digit in str(number) ])




############################################

if __name__ == "__main__":

    app_id = FB_APP_ID
    app_token = get_app_token(app_id, FB_APP_SECRET)              

    parser = argparse.ArgumentParser()
    parser.add_argument('--create')
    parser.add_argument('--createn', type=int)
    parser.add_argument('--labelname', nargs='+')
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--token', action='store_true')
    parser.add_argument('--friends', nargs='+')
    args = parser.parse_args()

    if args.create:
        name = args.create
        info = create_test_user(app_id, app_token, name)

    if args.createn:
        num = args.createn
        fbid__data = {}
        for i in range(num):
            data = create_test_user(app_id, app_token)
            fbid__data[data['id']] = data
        print "made %d users:" % len(fbid__data)
        print " ".join(fbid__data.keys())

        # make 'em all friends
        link_count = make_friends(fbid__data.values())
        print "made %d relationships" % link_count

    if args.friends:
        fbids = args.friends
        fbdatas = get_test_users(app_id, app_token)  # each entry has: id, access_token, login_url
        fbid__data = list_to_dict(fbdatas, 'id')
        link_count = make_friends([fbid__data[fbid] for fbid in fbids])
        print "made %d relationships between %d users" % (link_count, len(fbids))

    if args.list:
        fbdatas = get_test_users(app_id, app_token)  # each entry has: id, access_token, login_url
        fbid__data = list_to_dict(fbdatas, 'id')

        fbdetails = infos_from_fbids([user['id'] for user in fbdatas], app_token)
        for info in fbdetails:
            data = fbid__data[info['id']]
            fields = [info.get(f, "") for f in ['id', 'first_name', 'last_name', 'gender',
                                                'birthday']]
            fields.append(info.get('location', {}).get('name', ""))
            fields.extend([data['login_url'], data.get('access_token', "")])
            print "\t".join(fields) + "\n"

    if args.token:
        print "app token: " + app_token

    if args.labelname:
        fbdatas = get_test_users(app_id, app_token)  # each entry has: id, access_token, login_url
        fbid__data = list_to_dict(fbdatas, 'id')

        for fbid in args.labelname:
            label_name(fbid, fbid__data[fbid]['access_token'])


    






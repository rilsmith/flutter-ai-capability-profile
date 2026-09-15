#!/usr/bin/env python3
"""Simple LDAP user lookup against ldap.loc.adobe.net."""

import json
import sys
from ldap3 import Server, Connection, ALL, SUBTREE

LDAP_URL = "ldap://ldap.loc.adobe.net"
BASE_DN = "o=adbe"


def find_direct_reports(conn, employee) -> list:
    dn = employee.entry_dn
    # this directory stores manager as bare cn=<uid> with no OU suffix
    rdn = dn.split(",")[0]
    search_filter = f"(manager={rdn})"

    attributes = ["uid", "displayName", "mail", "manager"]
    conn.search(BASE_DN, search_filter, search_scope=SUBTREE, attributes=attributes)
    return list(conn.entries)


def build_org_tree(conn, employee, visited=None):
    if visited is None:
        visited = set()

    if employee.entry_dn in visited:
        return None

    visited.add(employee.entry_dn)

    employee_data = {
        "dn": employee.entry_dn,
        "uid": employee.uid.value if "uid" in employee else None,
        "name": employee.displayName.value if "displayName" in employee else None,
        "email": employee.mail.value if "mail" in employee else None,
        "reports": [],
    }

    for report in find_direct_reports(conn, employee):
        child = build_org_tree(conn, report, visited)
        if child:
            employee_data["reports"].append(child)

    return employee_data


def lookup_user(username: str, bind_dn: str = None, bind_pw: str = None) -> None:
    server = Server(LDAP_URL, get_info=ALL)

    conn = Connection(server, user=bind_dn, password=bind_pw, auto_bind=True)

    search_filter = f"(|(uid={username})(mail={username}))"
    # fetch all attributes for the root entry
    conn.search(BASE_DN, search_filter, search_scope=SUBTREE, attributes=["*"])

    if not conn.entries:
        print(f"No entries found for: {username}")
        conn.unbind()
        return

    tree = build_org_tree(conn, conn.entries[0])
    print(json.dumps(tree, indent=2))

    conn.unbind()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <username|email> [bind_dn] [bind_password]")
        print(f"Example: {sys.argv[0]} jdoe")
        sys.exit(1)

    username = sys.argv[1]
    bind_dn  = sys.argv[2] if len(sys.argv) > 2 else None
    bind_pw  = sys.argv[3] if len(sys.argv) > 3 else None

    lookup_user(username, bind_dn, bind_pw)

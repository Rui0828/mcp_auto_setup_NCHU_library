import requests
import urllib.parse
import time
import re
from mcp.server.fastmcp import FastMCP


# This is a simple example of a FastMCP tool that searches for books in the NCHU library using the Primo API.
mcp = FastMCP("NCHU_library")

@mcp.tool()
def search_nchu_library_books(query: str):
    """
    Search books from the NCHU (National Chung Hsing University) Library using the Primo API.

    Args:
        query (str): The keyword to search for (supports Chinese characters).

    Returns:
        List[dict]: A list of dictionaries, each containing:
            - 'title': The book title (cleaned).
            - 'creator': The main creator or contributor name (cleaned, $$Q metadata removed).
            - 'link': The alma link to the detailed page of the book.
            - or an 'error' field if a request fails.
    """
    total_count: int = 10 
    page_size: int = 10


    base_url = "https://nchu.primo.exlibrisgroup.com/primaws/rest/pub/pnxs"
    encoded_query = urllib.parse.quote(query)
    results = []

    for offset in range(0, total_count, page_size):
        url = (
            f"{base_url}?acTriggered=false&blendFacetsSeparately=false"
            f"&came_from=pagination_1_2&citationTrailFilterByAvailability=true"
            f"&disableCache=false&getMore=0&inst=886NCHU_INST&isCDSearch=false"
            f"&lang=zh-tw&limit={page_size}&newspapersActive=false&newspapersSearch=false"
            f"&offset={offset}&otbRanking=false&pcAvailability=false"
            f"&q=any,contains,{encoded_query}&qExclude=&qInclude="
            f"&rapido=false&refEntryActive=false&rtaLinks=true"
            f"&scope=MyInst_and_CI&searchInFulltextUserSelection=false"
            f"&skipDelivery=Y&sort=rank&tab=Everything&vid=886NCHU_INST:886NCHU_INST"
        )

        try:
            response = requests.get(url)
            response.raise_for_status()
            data = response.json()
            for doc in data.get("docs", []):
                display = doc.get("pnx", {}).get("display", {})
                links = doc.get("pnx", {}).get("links", {})

                title = display.get("title", [""])[0]

                # 優先 creator，否則用 contributor
                creator_list = display.get("creator") or display.get("contributor", [""])
                creator = creator_list[0] if creator_list else ""

                # 移除 $$Q 及後面的文字
                creator_clean = re.sub(r"\$\$Q.*", "", creator).strip()
                
                # 取得 Alma 連結
                record_id = doc.get("pnx", {}).get("control", {}).get("recordid", [""])[0]
                alma_link = f"https://nchu.primo.exlibrisgroup.com/discovery/fulldisplay?docid={record_id}&context=PC&vid=886NCHU_INST:886NCHU_INST&lang=zh-tw"

                # 也可以嘗試從 links 中獲取連結
                if not record_id and links.get("linktorsrc"):
                    for link_data in links.get("linktorsrc", []):
                        match = re.search(r'\$\$U(.*?)\$\$', link_data)
                        if match:
                            alma_link = match.group(1)
                            break

                results.append({
                    "title": title.strip(),
                    "creator": creator_clean,
                    "link": alma_link
                })

            time.sleep(1)  # 防止被封鎖
        except Exception as e:
            results.append({"error": str(e), "offset": offset})

    return results

if __name__ == "__main__":
    # Initialize and run the server
    mcp.run(transport='stdio')
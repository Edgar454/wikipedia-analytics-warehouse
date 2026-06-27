from pydantic import BaseModel

class Credentials(BaseModel):
    TENANT_ID:str 
    CLIENT_ID:str
    CLIENT_SECRET:str
    WORKSPACE_NAME:str
    DATASET_NAME:str

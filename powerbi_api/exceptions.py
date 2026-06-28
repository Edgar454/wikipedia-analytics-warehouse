class PowerBIImportTimeoutError(TimeoutError):
    """
    Raised when a .pbix import never reaches a terminal state
    (Succeeded/Failed) within the allotted polling attempts.

    Distinct from RuntimeError("Import failed") -- that means Power BI
    told us it failed. This means we genuinely don't know; we just
    ran out of patience waiting for an answer.
    """

    def __init__(self, import_id: str, last_state: str, attempts: int):
        self.import_id = import_id
        self.last_state = last_state
        self.attempts = attempts
        super().__init__(
            f"Import {import_id} did not complete after {attempts} polls "
            f"(last state: '{last_state}')."
        )